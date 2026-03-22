-- Sangha Social Layer: sanghas and sangha_members
-- Run in Supabase Dashboard → SQL Editor

create table if not exists public.sanghas (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  invite_code text unique not null
);

create table if not exists public.sangha_members (
  sangha_id uuid not null references public.sanghas(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  role text not null default 'member' check (role in ('creator', 'member')),
  primary key (sangha_id, user_id)
);

-- Enable RLS
alter table public.sanghas enable row level security;
alter table public.sangha_members enable row level security;

-- Sanghas: creators can manage; members can read
create policy "Members can read sanghas"
  on public.sanghas for select
  using (
    exists (
      select 1 from public.sangha_members sm
      where sm.sangha_id = sanghas.id and sm.user_id = auth.uid()
    )
  );

create policy "Creators can insert sanghas"
  on public.sanghas for insert
  with check (auth.uid() = created_by);

create policy "Creators can update own sanghas"
  on public.sanghas for update
  using (auth.uid() = created_by);

create policy "Creators can delete own sanghas"
  on public.sanghas for delete
  using (auth.uid() = created_by);

-- Sangha members: members can read; creators can insert/update
create policy "Members can read sangha_members"
  on public.sangha_members for select
  using (
    exists (
      select 1 from public.sangha_members sm
      where sm.sangha_id = sangha_members.sangha_id and sm.user_id = auth.uid()
    )
  );

create policy "Creators can insert sangha_members"
  on public.sangha_members for insert
  with check (
    -- Sangha creator inserting themselves as creator (no members exist yet)
    (exists (select 1 from sanghas s where s.id = sangha_members.sangha_id and s.created_by = auth.uid())
     and user_id = auth.uid() and role = 'creator')
    or
    -- Sangha creator inserting another member
    exists (select 1 from sangha_members sm where sm.sangha_id = sangha_members.sangha_id and sm.user_id = auth.uid() and sm.role = 'creator')
  );

create policy "Creators can update sangha_members"
  on public.sangha_members for update
  using (
    exists (
      select 1 from public.sangha_members sm
      where sm.sangha_id = sangha_members.sangha_id and sm.user_id = auth.uid() and sm.role = 'creator'
    )
  );

create policy "Users can delete own membership"
  on public.sangha_members for delete
  using (auth.uid() = user_id);

-- Allow joining via invite: user inserts themselves into sangha_members when they have valid invite_code
-- We need a policy that allows insert when the sangha exists and invite_code matches
-- Simpler: use a service role or RPC for join. For v1, we'll use a policy that allows
-- insert when sangha.invite_code matches (we pass it) - but RLS can't easily check that from client.
-- Alternative: create a join_sangha RPC that uses service role internally.
-- For v1: Allow users to insert themselves into sangha_members if the sangha's invite_code
-- was provided. We can't pass invite_code to RLS directly. Use a simpler approach:
-- Policy: Allow insert when user_id = auth.uid() - but we need to verify they have the code.
-- The app will: 1) fetch sangha by invite_code (need a policy for that), 2) insert into sangha_members.
-- For "fetch sangha by invite_code" we need: anyone can read a sangha if they know the invite_code?
-- That would expose sangha names. Better: create a Postgres function join_sangha(invite_code text)
-- that 1) finds sangha by code, 2) inserts into sangha_members, 3) runs as definer with elevated privileges.
-- Simpler v1: Allow SELECT on sanghas where we're matching by invite_code - but that's a leak.
-- Plan says: "On join: SanghaService.joinSangha(inviteCode:) → insert into sangha_members"
-- So we need to: 1) find sangha by invite_code (anon or authenticated?), 2) insert member.
-- For finding: we could have an RPC get_sangha_by_invite_code(code) that returns id if valid.
-- Or: allow SELECT on sanghas for rows where invite_code = X - but we'd need to pass X.
-- Postgres RLS: we can't pass parameters. So we need an RPC.
-- Create: rpc.join_sangha_by_code(p_invite_code text) returns sangha_id uuid
-- Body: find sangha where invite_code = p_invite_code, insert into sangha_members (sangha_id, auth.uid(), 'member'), return sangha_id.
-- Security: runs with definer (postgres) so bypasses RLS. Only allow auth.uid() to be inserted.
create or replace function public.join_sangha_by_code(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sangha_id uuid;
begin
  select id into v_sangha_id from sanghas where invite_code = p_invite_code limit 1;
  if v_sangha_id is null then
    raise exception 'Invalid invite code';
  end if;
  insert into sangha_members (sangha_id, user_id, role)
  values (v_sangha_id, auth.uid(), 'member')
  on conflict (sangha_id, user_id) do nothing;
  return v_sangha_id;
end;
$$;

-- Indexes
create index if not exists sanghas_invite_code_idx on public.sanghas(invite_code);
create index if not exists sanghas_created_by_idx on public.sanghas(created_by);
create index if not exists sangha_members_sangha_id_idx on public.sangha_members(sangha_id);
create index if not exists sangha_members_user_id_idx on public.sangha_members(user_id);
