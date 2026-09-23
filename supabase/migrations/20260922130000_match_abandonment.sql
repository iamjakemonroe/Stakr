-- Closes the abandonment gap called out at the bottom of
-- 20260922120000_chess_social_schema.sql: an active match with a silent
-- opponent currently sits locked forever, stakes and all. This adds a
-- scheduled sweep (pg_cron, Postgres-native — no edge function or external
-- scheduler needed) that forfeits a match to whoever's opponent has gone
-- quiet for too long.
--
-- Threshold: 15 minutes since the last move (or since the match started, if
-- no move has been made yet). That fits live/near-live play, which is the
-- model the client is built for (realtime board sync, "waiting for
-- opponent" turn indicator) — not correspondence-style days-long games. If
-- Stakr ever adds an async/correspondence mode, this threshold needs to be
-- per-match, not global; tracked as a follow-up, not solved here.

create extension if not exists pg_cron with schema extensions;

create function public.forfeit_abandoned_matches()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match record;
  v_last_activity timestamptz;
  v_winner uuid;
begin
  for v_match in select * from public.matches where status = 'active' loop
    select max(created_at) into v_last_activity
      from public.match_moves where match_id = v_match.id;
    v_last_activity := coalesce(v_last_activity, v_match.started_at, v_match.created_at);

    continue when v_last_activity >= now() - interval '15 minutes';

    -- ply_count is even (0, 2, 4, ...) when it's white to move next (white
    -- made the last odd-numbered ply, or no moves yet); forfeit goes to
    -- whoever was NOT on the clock, since they're the one still here.
    v_winner := case
      when v_match.ply_count % 2 = 0 then v_match.player_black
      else v_match.player_white
    end;

    if v_winner is not null then
      perform public._settle(v_match.id, v_winner, 'timeout');
    end if;
  end loop;
end;
$$;

comment on function public.forfeit_abandoned_matches is 'Run by pg_cron every 5 minutes (see the cron.schedule call below), not callable by clients — it settles matches, so it follows the same SECURITY DEFINER + no-client-access pattern as everything else that moves coins.';

revoke all on function public.forfeit_abandoned_matches() from public, authenticated, anon;

select cron.schedule(
  'forfeit-abandoned-chess-matches',
  '*/5 * * * *',
  $$select public.forfeit_abandoned_matches();$$
);
