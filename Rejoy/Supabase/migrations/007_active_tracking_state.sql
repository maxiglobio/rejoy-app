-- Sangha Social Layer: active_tracking_state for live "active now" status
-- Run in Supabase Dashboard → SQL Editor

create table if not exists public.active_tracking_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  activity_type_id uuid not null references public.activity_types(id) on delete cascade,
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Enable RLS
alter table public.active_tracking_state enable row level security;

-- Users can read/write only their own row
create policy "Users can read own active_tracking_state"
  on public.active_tracking_state for select
  using (auth.uid() = user_id);

create policy "Users can insert own active_tracking_state"
  on public.active_tracking_state for insert
  with check (auth.uid() = user_id);

create policy "Users can update own active_tracking_state"
  on public.active_tracking_state for update
  using (auth.uid() = user_id);

create policy "Users can delete own active_tracking_state"
  on public.active_tracking_state for delete
  using (auth.uid() = user_id);

-- Sangha members need to read other members' active_tracking_state
-- Allow select for user_ids that are in the same sangha as auth.uid()
create policy "Sangha members can read each other active_tracking_state"
  on public.active_tracking_state for select
  using (
    user_id = auth.uid()
    or
    exists (
      select 1 from sangha_members sm1
      join sangha_members sm2 on sm1.sangha_id = sm2.sangha_id
      where sm1.user_id = auth.uid()
        and sm2.user_id = active_tracking_state.user_id
    )
  );
