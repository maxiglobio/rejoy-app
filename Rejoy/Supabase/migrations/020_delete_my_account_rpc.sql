-- Account deletion for App Store Guideline 5.1.1(v)
-- Run in Supabase Dashboard → SQL Editor (once per project).
--
-- Deletes the authenticated user from auth.users. Existing FKs use ON DELETE CASCADE
-- for public tables (profiles, sessions, sangha_members, etc.).

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
