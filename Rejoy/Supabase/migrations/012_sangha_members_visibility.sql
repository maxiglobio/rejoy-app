-- Add visibility flag to sangha_members; update RLS to respect it.
-- Run in Supabase Dashboard → SQL Editor

-- Add column
alter table public.sangha_members add column if not exists is_visible boolean not null default true;

-- Drop existing sangha cross-read policies (we'll recreate with is_visible check)
drop policy if exists "Sangha members can read each other sessions" on public.sessions;
drop policy if exists "Sangha members can read each other profiles" on public.profiles;

-- Sessions: sangha members can read each other's sessions only when target is visible
create policy "Sangha members can read each other sessions"
  on public.sessions for select
  using (
    user_id = auth.uid()
    or
    exists (
      select 1 from sangha_members sm1
      join sangha_members sm2 on sm1.sangha_id = sm2.sangha_id and sm2.is_visible = true
      where sm1.user_id = auth.uid()
        and sm2.user_id = sessions.user_id
    )
  );

-- Profiles: sangha members can read each other's profiles only when target is visible
create policy "Sangha members can read each other profiles"
  on public.profiles for select
  using (
    id = auth.uid()
    or exists (
      select 1 from sangha_members sm1
      join sangha_members sm2 on sm1.sangha_id = sm2.sangha_id and sm2.is_visible = true
      where sm1.user_id = auth.uid()
        and sm2.user_id = profiles.id
    )
  );
