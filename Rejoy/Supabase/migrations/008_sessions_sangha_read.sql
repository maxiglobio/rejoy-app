-- Allow Sangha members to read each other's sessions (for story viewer)
-- Existing policy "Users can manage own sessions" covers own sessions.
-- Add policy for reading sessions of sangha members.

create policy "Sangha members can read each other sessions"
  on public.sessions for select
  using (
    user_id = auth.uid()
    or
    exists (
      select 1 from sangha_members sm1
      join sangha_members sm2 on sm1.sangha_id = sm2.sangha_id
      where sm1.user_id = auth.uid()
        and sm2.user_id = sessions.user_id
    )
  );
