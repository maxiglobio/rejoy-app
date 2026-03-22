-- Allow sangha members to read each other's activity types (for Karma Partners to show custom activities).
-- Existing policy covers built-in (user_id null) and own. Add sangha cross-read.

create policy "Sangha members can read each other activity types"
  on public.activity_types for select
  using (
    user_id is null
    or user_id = auth.uid()
    or exists (
      select 1 from sangha_members sm1
      join sangha_members sm2 on sm1.sangha_id = sm2.sangha_id and sm2.is_visible = true
      where sm1.user_id = auth.uid()
        and sm2.user_id = activity_types.user_id
    )
  );
