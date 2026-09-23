-- The new chess/social tables were never added to the `supabase_realtime`
-- publication, so every client `.stream()` subscription on them (match
-- state, move sync, invite notifications) failed immediately with an
-- unhandled RealtimeSubscribeException the moment the UI tried to watch
-- them — caught live while running the app against this project for the
-- first time. `profiles` realtime already worked, but evidently via a
-- dashboard toggle rather than a migration (no ALTER PUBLICATION statement
-- exists for it in this repo's history) — that's exactly the kind of
-- undocumented manual step that's invisible until a fresh environment
-- (or a fresh reviewer) hits it. Doing it in SQL here so it travels with
-- the schema instead of living only in one project's dashboard state.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'matches'
  ) then
    alter publication supabase_realtime add table public.matches;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'match_moves'
  ) then
    alter publication supabase_realtime add table public.match_moves;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'match_invites'
  ) then
    alter publication supabase_realtime add table public.match_invites;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'matchmaking_queue'
  ) then
    alter publication supabase_realtime add table public.matchmaking_queue;
  end if;
end $$;
