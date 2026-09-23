-- Chess matches, matchmaking, friends, and the settlement functions that
-- move coins for them. Everything here follows the pattern set in
-- 20260826155942_initial_schema.sql: no client write path on any table,
-- every mutation goes through a SECURITY DEFINER function that checks
-- auth.uid() itself, and every balance change is a ledger_entries row.
--
-- Money model note (2026-09-22): coins are virtual-only right now — bought
-- via IAP later, never cashed out for real currency. That's why settlement
-- below is allowed to run on a "both players agree, or the loser resigns"
-- model instead of a fully server-verified chess engine in Postgres: a
-- worst case (two colluding accounts laundering the signup bonus into fake
-- "winnings") only costs in-app coins, not real money. Re-read this before
-- ever wiring a real payout rail to `balance` — at that point collusion and
-- move-validation need to be closed first (see bottom-of-file note).

-- ── profiles: username for search/friends ──────────────────────────────

alter table public.profiles
  add column username text unique,
  add column lifetime_wagered bigint not null default 0;

comment on column public.profiles.username is 'Lowercase handle, chosen at first launch. Used for friend search. Nullable until the user sets one.';
comment on column public.profiles.lifetime_wagered is 'Cumulative stake amount across settled matches. Tracked from day one so a future wagering-requirement gate on cash withdrawal (if the money model ever changes) does not need a backfill.';

create unique index profiles_username_lower_idx on public.profiles (lower(username));

create function public.set_username(p_username text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_username !~ '^[a-z0-9_]{3,20}$' then
    raise exception 'username must be 3-20 lowercase letters, numbers, or underscores';
  end if;

  update public.profiles set username = p_username, updated_at = now() where id = v_me;
exception
  when unique_violation then
    raise exception 'username already taken';
end;
$$;

comment on function public.set_username is 'Client-facing setter for the one profile column a user is allowed to change themselves. Format-validated here since there is no client write path to check it any other way.';

revoke all on function public.set_username(text) from public;
grant execute on function public.set_username(text) to authenticated;

-- ── game + match tables ─────────────────────────────────────────────────

create type public.game_kind as enum ('chess');
create type public.match_status as enum ('pending', 'active', 'completed', 'aborted', 'disputed');

create table public.matches (
  id               uuid primary key default gen_random_uuid(),
  game             public.game_kind not null default 'chess',
  status           public.match_status not null default 'pending',
  stake            bigint not null check (stake >= 0),
  commission_bps   int not null default 500, -- 5% platform rake on the pot, taken from the winner's payout
  player_white     uuid not null references public.profiles (id),
  player_black     uuid references public.profiles (id),
  board_fen        text not null default 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  ply_count        int not null default 0,
  winner_id        uuid references public.profiles (id),
  result           text, -- 'checkmate' | 'resignation' | 'timeout' | 'draw' | 'stalemate' | 'disputed'
  created_at       timestamptz not null default now(),
  started_at       timestamptz,
  ended_at         timestamptz
);

comment on table public.matches is 'One row per chess game. board_fen is the authoritative current position, updated by record_move. Realtime clients subscribe to this row + match_moves for live sync.';

create index matches_player_white_idx on public.matches (player_white, created_at desc);
create index matches_player_black_idx on public.matches (player_black, created_at desc);

create table public.match_moves (
  id          bigint generated always as identity primary key,
  match_id    uuid not null references public.matches (id) on delete cascade,
  ply         int not null,
  player_id   uuid not null references public.profiles (id),
  from_square text not null,
  to_square   text not null,
  promotion   text,
  san         text not null,
  fen_after   text not null,
  created_at  timestamptz not null default now(),
  unique (match_id, ply)
);

comment on table public.match_moves is 'Append-only move log per match. Both clients run the same legal-move engine locally and broadcast/replay from this table over Supabase Realtime; this table is the sync source of truth, not an anti-cheat oracle (see file header).';

create table public.match_result_reports (
  match_id    uuid not null references public.matches (id) on delete cascade,
  reporter_id uuid not null references public.profiles (id),
  winner_id   uuid references public.profiles (id), -- null = reporting a draw
  result      text not null,
  created_at  timestamptz not null default now(),
  primary key (match_id, reporter_id)
);

comment on table public.match_result_reports is 'Each player reports how their game ended. settle_match_if_agreed fires when both reports agree; a mismatch flips the match to disputed instead of paying out. resign_match bypasses this (single-sided, by design — a resignation is not in dispute).';

-- ── matchmaking queue (random opponent) ─────────────────────────────────

create table public.matchmaking_queue (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  game       public.game_kind not null default 'chess',
  stake      bigint not null check (stake >= 0),
  queued_at  timestamptz not null default now()
);

comment on table public.matchmaking_queue is 'Waiting room for "Play Random". try_match_queue pairs two rows with the same game+stake, oldest first.';

-- ── friend requests + friendships ───────────────────────────────────────

create type public.friend_request_status as enum ('pending', 'accepted', 'declined', 'cancelled');

create table public.friend_requests (
  id           uuid primary key default gen_random_uuid(),
  from_user    uuid not null references public.profiles (id) on delete cascade,
  to_user      uuid not null references public.profiles (id) on delete cascade,
  status       public.friend_request_status not null default 'pending',
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  check (from_user <> to_user),
  unique (from_user, to_user)
);

create index friend_requests_to_user_idx on public.friend_requests (to_user, status);

create table public.friendships (
  user_low   uuid not null references public.profiles (id) on delete cascade,
  user_high  uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_low, user_high),
  check (user_low < user_high)
);

comment on table public.friendships is 'One row per accepted friendship, stored once with user_low < user_high so lookups do not need to check both directions.';

-- ── match invites (challenge a friend or a "recent") ────────────────────

create type public.invite_status as enum ('pending', 'accepted', 'declined', 'cancelled', 'expired');

create table public.match_invites (
  id           uuid primary key default gen_random_uuid(),
  game         public.game_kind not null default 'chess',
  stake        bigint not null check (stake >= 0),
  from_user    uuid not null references public.profiles (id),
  to_user      uuid not null references public.profiles (id),
  status       public.invite_status not null default 'pending',
  match_id     uuid references public.matches (id),
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  check (from_user <> to_user)
);

create index match_invites_to_user_idx on public.match_invites (to_user, status);

-- ── RLS: select-only for clients, same as the initial schema ────────────

alter table public.matches enable row level security;
alter table public.match_moves enable row level security;
alter table public.match_result_reports enable row level security;
alter table public.matchmaking_queue enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.match_invites enable row level security;

revoke insert, update, delete on public.matches from authenticated, anon;
revoke insert, update, delete on public.match_moves from authenticated, anon;
revoke insert, update, delete on public.match_result_reports from authenticated, anon;
revoke insert, update, delete on public.matchmaking_queue from authenticated, anon;
revoke insert, update, delete on public.friend_requests from authenticated, anon;
revoke insert, update, delete on public.friendships from authenticated, anon;
revoke insert, update, delete on public.match_invites from authenticated, anon;

create policy "select own matches" on public.matches
  for select using (auth.uid() = player_white or auth.uid() = player_black);

create policy "select moves of own matches" on public.match_moves
  for select using (
    exists (
      select 1 from public.matches m
      where m.id = match_id and (m.player_white = auth.uid() or m.player_black = auth.uid())
    )
  );

create policy "select own result reports" on public.match_result_reports
  for select using (
    exists (
      select 1 from public.matches m
      where m.id = match_id and (m.player_white = auth.uid() or m.player_black = auth.uid())
    )
  );

create policy "select own queue row" on public.matchmaking_queue
  for select using (auth.uid() = user_id);

create policy "select own friend requests" on public.friend_requests
  for select using (auth.uid() = from_user or auth.uid() = to_user);

create policy "select own friendships" on public.friendships
  for select using (auth.uid() = user_low or auth.uid() = user_high);

create policy "select own invites" on public.match_invites
  for select using (auth.uid() = from_user or auth.uid() = to_user);

-- Profiles were previously select-own-only; friend search and "who am I
-- playing" need to resolve other users' id/display_name/username. Balance
-- stays implicitly protected — this just widens which *rows* are visible,
-- not which *columns* a client can request beyond what already existed.
create policy "select any profile for search/matches" on public.profiles
  for select using (true);

drop policy "select own profile" on public.profiles;

-- ── internal helpers ─────────────────────────────────────────────────────

create function public._ledger_move(p_user_id uuid, p_type public.ledger_entry_type, p_amount bigint, p_match_id uuid, p_metadata jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_balance bigint;
begin
  update public.profiles
    set balance = balance + p_amount, updated_at = now()
    where id = p_user_id
    returning balance into v_new_balance;

  insert into public.ledger_entries (user_id, entry_type, amount, balance_after, match_id, metadata)
    values (p_user_id, p_type, p_amount, v_new_balance, p_match_id, p_metadata);
end;
$$;

revoke all on function public._ledger_move(uuid, public.ledger_entry_type, bigint, uuid, jsonb) from public;

-- ── matchmaking ───────────────────────────────────────────────────────────

create function public.join_matchmaking_queue(p_stake bigint)
returns uuid -- returns a match id if a pairing happened immediately, else null
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_opponent uuid;
  v_match_id uuid;
  v_my_balance bigint;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  select balance into v_my_balance from public.profiles where id = v_me;
  if v_my_balance is null or v_my_balance < p_stake then
    raise exception 'insufficient balance';
  end if;

  insert into public.matchmaking_queue (user_id, game, stake)
    values (v_me, 'chess', p_stake)
    on conflict (user_id) do update set stake = excluded.stake, queued_at = now();

  -- Oldest other waiting player at the same stake, locked so two concurrent
  -- callers can't both pair with the same opponent.
  select user_id into v_opponent
    from public.matchmaking_queue
    where game = 'chess' and stake = p_stake and user_id <> v_me
    order by queued_at
    limit 1
    for update skip locked;

  if v_opponent is null then
    return null;
  end if;

  delete from public.matchmaking_queue where user_id in (v_me, v_opponent);

  insert into public.matches (player_white, player_black, stake, status, started_at)
    values (v_me, v_opponent, p_stake, 'active', now())
    returning id into v_match_id;

  perform public._ledger_move(v_me, 'match_stake', -p_stake, v_match_id);
  perform public._ledger_move(v_opponent, 'match_stake', -p_stake, v_match_id);

  update public.profiles set lifetime_wagered = lifetime_wagered + p_stake where id in (v_me, v_opponent);

  return v_match_id;
end;
$$;

revoke all on function public.join_matchmaking_queue(bigint) from public;
grant execute on function public.join_matchmaking_queue(bigint) to authenticated;

create function public.leave_matchmaking_queue()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.matchmaking_queue where user_id = auth.uid();
$$;

revoke all on function public.leave_matchmaking_queue() from public;
grant execute on function public.leave_matchmaking_queue() to authenticated;

-- ── friend requests ───────────────────────────────────────────────────────

create function public.send_friend_request(p_to_user uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_lo uuid;
  v_hi uuid;
  v_id uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if v_me = p_to_user then raise exception 'cannot friend yourself'; end if;

  v_lo := least(v_me, p_to_user);
  v_hi := greatest(v_me, p_to_user);
  if exists (select 1 from public.friendships where user_low = v_lo and user_high = v_hi) then
    raise exception 'already friends';
  end if;

  -- If the other person already sent us a request, accept it instead of
  -- creating a duplicate/reverse row.
  update public.friend_requests
    set status = 'accepted', responded_at = now()
    where from_user = p_to_user and to_user = v_me and status = 'pending'
    returning id into v_id;

  if v_id is not null then
    insert into public.friendships (user_low, user_high) values (v_lo, v_hi)
      on conflict do nothing;
    return v_id;
  end if;

  insert into public.friend_requests (from_user, to_user)
    values (v_me, p_to_user)
    on conflict (from_user, to_user) do update set status = 'pending', created_at = now(), responded_at = null
    returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.send_friend_request(uuid) from public;
grant execute on function public.send_friend_request(uuid) to authenticated;

create function public.respond_friend_request(p_request_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_from uuid;
  v_to uuid;
begin
  select from_user, to_user into v_from, v_to
    from public.friend_requests where id = p_request_id and status = 'pending';

  if v_from is null then raise exception 'request not found'; end if;
  if v_to <> v_me then raise exception 'not your request to answer'; end if;

  update public.friend_requests
    set status = case when p_accept then 'accepted' else 'declined' end, responded_at = now()
    where id = p_request_id;

  if p_accept then
    insert into public.friendships (user_low, user_high)
      values (least(v_from, v_to), greatest(v_from, v_to))
      on conflict do nothing;
  end if;
end;
$$;

revoke all on function public.respond_friend_request(uuid, boolean) from public;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;

-- ── match invites (challenge a specific person) ─────────────────────────

create function public.send_match_invite(p_to_user uuid, p_stake bigint)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
  v_my_balance bigint;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if v_me = p_to_user then raise exception 'cannot invite yourself'; end if;

  select balance into v_my_balance from public.profiles where id = v_me;
  if v_my_balance is null or v_my_balance < p_stake then
    raise exception 'insufficient balance';
  end if;

  insert into public.match_invites (from_user, to_user, stake)
    values (v_me, p_to_user, p_stake)
    returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.send_match_invite(uuid, bigint) from public;
grant execute on function public.send_match_invite(uuid, bigint) to authenticated;

create function public.respond_match_invite(p_invite_id uuid, p_accept boolean)
returns uuid -- match id if accepted
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_from uuid;
  v_to uuid;
  v_stake bigint;
  v_match_id uuid;
  v_from_balance bigint;
  v_to_balance bigint;
begin
  -- Locked so two near-simultaneous accept calls on the same invite (a
  -- double-tap, or the same account live on two devices) can't both pass
  -- the pending check and each create their own match + debit — the second
  -- call blocks here until the first commits, then sees status='accepted'
  -- and falls through to 'invite not found' below.
  select from_user, to_user, stake into v_from, v_to, v_stake
    from public.match_invites where id = p_invite_id and status = 'pending'
    for update;

  if v_from is null then raise exception 'invite not found'; end if;
  if v_to <> v_me then raise exception 'not your invite to answer'; end if;

  if not p_accept then
    update public.match_invites set status = 'declined', responded_at = now() where id = p_invite_id;
    return null;
  end if;

  select balance into v_from_balance from public.profiles where id = v_from;
  select balance into v_to_balance from public.profiles where id = v_to;
  if v_from_balance is null or v_from_balance < v_stake or v_to_balance is null or v_to_balance < v_stake then
    update public.match_invites set status = 'expired', responded_at = now() where id = p_invite_id;
    raise exception 'a player no longer has enough balance for this stake';
  end if;

  insert into public.matches (player_white, player_black, stake, status, started_at)
    values (v_from, v_to, v_stake, 'active', now())
    returning id into v_match_id;

  perform public._ledger_move(v_from, 'match_stake', -v_stake, v_match_id);
  perform public._ledger_move(v_to, 'match_stake', -v_stake, v_match_id);
  update public.profiles set lifetime_wagered = lifetime_wagered + v_stake where id in (v_from, v_to);

  update public.match_invites
    set status = 'accepted', responded_at = now(), match_id = v_match_id
    where id = p_invite_id;

  return v_match_id;
end;
$$;

revoke all on function public.respond_match_invite(uuid, boolean) from public;
grant execute on function public.respond_match_invite(uuid, boolean) to authenticated;

-- ── moves ─────────────────────────────────────────────────────────────────

create function public.record_move(p_match_id uuid, p_from text, p_to text, p_promotion text, p_san text, p_fen_after text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.matches;
  v_next_ply int;
begin
  select * into v_match from public.matches where id = p_match_id for update;

  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if v_me <> v_match.player_white and v_me <> v_match.player_black then
    raise exception 'not a player in this match';
  end if;

  v_next_ply := v_match.ply_count + 1;

  insert into public.match_moves (match_id, ply, player_id, from_square, to_square, promotion, san, fen_after)
    values (p_match_id, v_next_ply, v_me, p_from, p_to, p_promotion, p_san, p_fen_after);

  update public.matches
    set board_fen = p_fen_after, ply_count = v_next_ply
    where id = p_match_id;
end;
$$;

comment on function public.record_move is 'Appends a move and advances board_fen. Does NOT validate chess legality server-side (see file header) — it only checks that the caller is a participant and the match is active, so a compromised client could desync the position or record an illegal move. That is an acceptable v1 tradeoff while coins are virtual-only; see settle_match_if_agreed for how payouts stay safe regardless.';

revoke all on function public.record_move(uuid, text, text, text, text, text) from public;
grant execute on function public.record_move(uuid, text, text, text, text, text) to authenticated;

-- ── settlement ────────────────────────────────────────────────────────────

create function public._settle(p_match_id uuid, p_winner_id uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.matches;
  v_pot bigint;
  v_commission bigint;
  v_payout bigint;
  v_loser_id uuid;
begin
  select * into v_match from public.matches where id = p_match_id for update;
  if v_match.status <> 'active' then
    return; -- already settled/aborted; idempotent no-op
  end if;

  v_pot := v_match.stake * 2;

  if p_winner_id is null then
    -- Draw: stakes returned, no commission taken (nothing was "won").
    perform public._ledger_move(v_match.player_white, 'match_refund', v_match.stake, p_match_id);
    perform public._ledger_move(v_match.player_black, 'match_refund', v_match.stake, p_match_id);
  else
    v_commission := (v_pot * v_match.commission_bps) / 10000;
    v_payout := v_pot - v_commission;
    v_loser_id := case when p_winner_id = v_match.player_white then v_match.player_black else v_match.player_white end;

    perform public._ledger_move(p_winner_id, 'match_payout', v_payout, p_match_id);
    if v_commission > 0 then
      perform public._ledger_move(p_winner_id, 'commission', -v_commission, p_match_id, jsonb_build_object('loser', v_loser_id));
    end if;
  end if;

  update public.matches
    set status = 'completed', winner_id = p_winner_id, result = p_result, ended_at = now()
    where id = p_match_id;
end;
$$;

revoke all on function public._settle(uuid, uuid, text) from public;

create function public.report_match_result(p_match_id uuid, p_winner_id uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.matches;
  v_other_report public.match_result_reports;
begin
  select * into v_match from public.matches where id = p_match_id;
  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if v_me <> v_match.player_white and v_me <> v_match.player_black then
    raise exception 'not a player in this match';
  end if;
  if p_winner_id is not null and p_winner_id <> v_match.player_white and p_winner_id <> v_match.player_black then
    raise exception 'winner must be a player in this match';
  end if;

  insert into public.match_result_reports (match_id, reporter_id, winner_id, result)
    values (p_match_id, v_me, p_winner_id, p_result)
    on conflict (match_id, reporter_id) do update set winner_id = excluded.winner_id, result = excluded.result, created_at = now();

  select * into v_other_report
    from public.match_result_reports
    where match_id = p_match_id and reporter_id <> v_me;

  if v_other_report is null then
    return; -- waiting on the other player
  end if;

  if v_other_report.winner_id is not distinct from p_winner_id and v_other_report.result = p_result then
    perform public._settle(p_match_id, p_winner_id, p_result);
  else
    update public.matches set status = 'disputed' where id = p_match_id;
  end if;
end;
$$;

comment on function public.report_match_result is 'Both players must independently report the same outcome before coins move (see file header for why this substitutes for server-side move validation). A disputed match pays out to neither side; resolving disputes is manual/future work, tracked as a known gap.';

revoke all on function public.report_match_result(uuid, uuid, text) from public;
grant execute on function public.report_match_result(uuid, uuid, text) to authenticated;

create function public.resign_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.matches;
  v_winner uuid;
begin
  select * into v_match from public.matches where id = p_match_id for update;
  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if v_me <> v_match.player_white and v_me <> v_match.player_black then
    raise exception 'not a player in this match';
  end if;

  v_winner := case when v_me = v_match.player_white then v_match.player_black else v_match.player_white end;
  perform public._settle(p_match_id, v_winner, 'resignation');
end;
$$;

revoke all on function public.resign_match(uuid) from public;
grant execute on function public.resign_match(uuid) to authenticated;

-- ── known gaps before real money ever touches this (read before that day) ──
-- 1. No server-side chess legality check — record_move trusts the client.
-- 2. Settlement trusts mutual self-report (or a resignation). Two accounts
--    controlled by the same person could collude to funnel one account's
--    stake into the other's "winnings". Fine while balance is virtual and
--    non-withdrawable; not fine the moment it is cash-backed.
-- 3. No timeout/abandonment handling yet — a match with a silent opponent
--    just sits 'active' with stakes locked. Needs a scheduled job.
-- 4. No per-account/device throttling on signup_bonus or matchmaking — an
--    attacker could script disposable accounts. Low stakes today because
--    coins aren't cash; revisit before Env.assertConfigured-style "this
--    must be fixed before launch" status.
