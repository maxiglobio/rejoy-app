-- Rejoy: User settings for restore after reinstall
-- Stores rejoy_meditation_time, rejoyed_session_ids, hidden_activity_type_ids

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  rejoy_meditation_time text,
  rejoyed_session_ids text,
  hidden_activity_type_ids text,
  updated_at timestamptz not null default now()
);

alter table public.user_settings enable row level security;

create policy "Users can read own user_settings"
  on public.user_settings for select
  using (auth.uid() = user_id);

create policy "Users can insert own user_settings"
  on public.user_settings for insert
  with check (auth.uid() = user_id);

create policy "Users can update own user_settings"
  on public.user_settings for update
  using (auth.uid() = user_id);
