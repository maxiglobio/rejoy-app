-- Allow sangha members to update their own is_visible (for "Pause my visibility").
-- Previously only creators could update sangha_members; regular members were blocked.

create policy "Members can update own visibility"
  on public.sangha_members for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
