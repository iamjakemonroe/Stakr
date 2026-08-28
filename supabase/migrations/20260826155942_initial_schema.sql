-- Stakr initial schema: profiles + coin ledger.
--
-- Design: profiles.balance is a denormalized cache column, mutated only
-- inside the same transaction as a ledger_entries insert. The ledger is the
-- append-only source of truth / audit trail; the balance column exists so
-- reads (UI, matchmaking eligibility checks) don't require aggregating the
-- ledger every time, and so a simple `check (balance >= 0)` guards against
-- overdraft. A row-lock on `UPDATE profiles ... WHERE id = ...` naturally
-- serializes concurrent mutations to the same user's balance.
--
-- No client write path exists on either table: RLS grants SELECT only, and
-- all mutations happen through SECURITY DEFINER functions (starting with
-- grant_starting_balance; later steps add place_stake / settle_match /
-- credit_purchase following the same pattern).

-- ── profiles ────────────────────────────────────────────────────────────

create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  balance      bigint not null default 0 check (balance >= 0),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.profiles is '1:1 extension of auth.users. balance is a denormalized cache kept in sync with ledger_entries by grant_starting_balance and future mutation functions.';

-- ── ledger_entries ──────────────────────────────────────────────────────

create type public.ledger_entry_type as enum (
  'signup_bonus',
  'purchase_credit',   -- IAP receipt-verified top-up (later step)
  'match_stake',        -- debit on entering a wagered match (later step)
  'match_payout',        -- credit to winner(s) (later step)
  'match_refund',         -- credit back on cancelled/aborted match (later step)
  'commission',            -- platform's cut (later step)
  'admin_adjustment'        -- manual correction
);

create table public.ledger_entries (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  entry_type    public.ledger_entry_type not null,
  amount        bigint not null,
  balance_after bigint not null,
  match_id      uuid, -- FK added once a `matches` table exists (later step)
  metadata      jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  constraint amount_nonzero check (amount <> 0)
);

comment on table public.ledger_entries is 'Append-only. amount is signed (positive = credit, negative = debit). balance_after is an audit snapshot, not a source of truth for the current balance.';

create index ledger_entries_user_id_idx on public.ledger_entries (user_id, created_at desc);

create function public.forbid_ledger_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'ledger_entries is append-only';
end;
$$;

create trigger ledger_entries_immutable
  before update or delete on public.ledger_entries
  for each row execute function public.forbid_ledger_mutation();

-- ── RLS ─────────────────────────────────────────────────────────────────

alter table public.profiles enable row level security;
alter table public.ledger_entries enable row level security;

-- Supabase's default schema grants are permissive (authenticated/anon get
-- table-level INSERT/UPDATE/DELETE by default); revoke explicitly so RLS
-- policies below are the only thing standing between a client and a write,
-- and there simply are no write policies for these roles.
revoke insert, update, delete on public.profiles from authenticated, anon;
revoke insert, update, delete on public.ledger_entries from authenticated, anon;

create policy "select own profile" on public.profiles
  for select using (auth.uid() = id);

create policy "select own ledger entries" on public.ledger_entries
  for select using (auth.uid() = user_id);

-- ── server-authoritative mutation ──────────────────────────────────────

create function public.grant_starting_balance(p_user_id uuid, p_amount bigint default 1000)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_balance bigint;
begin
  -- Idempotent: a user can only ever receive one signup bonus.
  if exists (
    select 1 from public.ledger_entries
    where user_id = p_user_id and entry_type = 'signup_bonus'
  ) then
    return;
  end if;

  update public.profiles
    set balance = balance + p_amount, updated_at = now()
    where id = p_user_id
    returning balance into v_new_balance;

  insert into public.ledger_entries (user_id, entry_type, amount, balance_after)
    values (p_user_id, 'signup_bonus', p_amount, v_new_balance);
end;
$$;

revoke all on function public.grant_starting_balance(uuid, bigint) from public;

-- ── new-user bootstrap ─────────────────────────────────────────────────

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id);
  perform public.grant_starting_balance(new.id, 1000);
  return new;
end;
$$;

-- Fires for every new auth.users row, including anonymous sign-ins, so the
-- starting balance is granted atomically with account creation with zero
-- client involvement.
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
