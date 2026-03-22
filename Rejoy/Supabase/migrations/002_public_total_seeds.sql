-- Public aggregate for marketing site: total seeds across all sessions.
-- Run in Supabase SQL Editor if you don’t use migration runner.
-- Safe: only exposes a single number, not row data (SECURITY DEFINER bypasses RLS for this query only).

create or replace function public.public_total_seeds()
returns bigint
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(sum(seeds), 0)::bigint from public.sessions;
$$;

comment on function public.public_total_seeds() is 'Marketing / stats: global sum of seeds; callable by anon for read-only counter.';

revoke all on function public.public_total_seeds() from public;
grant execute on function public.public_total_seeds() to anon, authenticated;
