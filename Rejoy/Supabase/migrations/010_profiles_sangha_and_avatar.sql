-- Add display_name to profiles; allow Sangha members to read each other's profiles.
-- Avatar uses existing teacher_portrait_url (same storage bucket).
-- Run in Supabase Dashboard → SQL Editor

-- Add column if not exist
alter table public.profiles add column if not exists display_name text;

-- Sangha members can read each other's profiles (for avatar strip, story viewer)
create policy "Sangha members can read each other profiles"
  on public.profiles for select
  using (
    id = auth.uid()
    or exists (
      select 1 from sangha_members sm1
      join sangha_members sm2 on sm1.sangha_id = sm2.sangha_id
      where sm1.user_id = auth.uid()
        and sm2.user_id = profiles.id
    )
  );
