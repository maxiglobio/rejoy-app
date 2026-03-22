-- Fix infinite recursion in sangha_members RLS policies.
-- Policies that query sangha_members from within sangha_members cause recursion.
-- Use SECURITY DEFINER functions to bypass RLS when checking membership.

-- Helper: check if current user is a member of the sangha (bypasses RLS)
create or replace function public.current_user_is_sangha_member(p_sangha_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from sangha_members
    where sangha_id = p_sangha_id and user_id = auth.uid()
  );
$$;

-- Helper: check if current user is the creator of the sangha (bypasses RLS)
create or replace function public.current_user_is_sangha_creator(p_sangha_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from sangha_members
    where sangha_id = p_sangha_id and user_id = auth.uid() and role = 'creator'
  );
$$;

-- Drop recursive policies
drop policy if exists "Members can read sanghas" on public.sanghas;
drop policy if exists "Members can read sangha_members" on public.sangha_members;
drop policy if exists "Creators can insert sangha_members" on public.sangha_members;
drop policy if exists "Creators can update sangha_members" on public.sangha_members;

-- Recreate sanghas read policy (creator or member can read)
create policy "Members can read sanghas"
  on public.sanghas for select
  using (
    created_by = auth.uid()
    or current_user_is_sangha_member(id)
  );

-- Recreate sangha_members policies (use helpers, no recursion)
create policy "Members can read sangha_members"
  on public.sangha_members for select
  using (current_user_is_sangha_member(sangha_id));

create policy "Creators can insert sangha_members"
  on public.sangha_members for insert
  with check (
    -- Sangha creator inserting themselves (no members exist yet - check sanghas table)
    (exists (select 1 from sanghas s where s.id = sangha_members.sangha_id and s.created_by = auth.uid())
     and user_id = auth.uid() and role = 'creator')
    or
    -- Existing creator inserting another member
    current_user_is_sangha_creator(sangha_id)
  );

create policy "Creators can update sangha_members"
  on public.sangha_members for update
  using (current_user_is_sangha_creator(sangha_id));
