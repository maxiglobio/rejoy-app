-- Rejoy: Initial schema for sessions and activity_types
-- Run this in Supabase Dashboard → SQL Editor

-- Activity types (matches SwiftData ActivityType)
create table if not exists public.activity_types (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  symbol_name text not null default 'circle',
  sort_order int not null default 0,
  is_built_in boolean not null default false,
  user_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Sessions (matches SwiftData Session)
create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  activity_type_id uuid not null references public.activity_types(id) on delete cascade,
  start_date timestamptz not null,
  end_date timestamptz not null,
  duration_seconds int not null,
  seeds int not null,
  dedication_text text not null default '',
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Enable RLS
alter table public.activity_types enable row level security;
alter table public.sessions enable row level security;

-- Users can read activity_types: built-in (user_id null) or own
create policy "Users can read activity_types"
  on public.activity_types for select
  using (user_id is null or auth.uid() = user_id);

create policy "Users can insert own activity_types"
  on public.activity_types for insert
  with check (auth.uid() = user_id);

create policy "Users can update own activity_types"
  on public.activity_types for update
  using (auth.uid() = user_id);

create policy "Users can delete own activity_types"
  on public.activity_types for delete
  using (auth.uid() = user_id);

-- Users can only access their own sessions
create policy "Users can manage own sessions"
  on public.sessions for all
  using (auth.uid() = user_id);

-- Index for faster queries
create index if not exists sessions_user_id_idx on public.sessions(user_id);
create index if not exists sessions_start_date_idx on public.sessions(start_date desc);
create index if not exists activity_types_user_id_idx on public.activity_types(user_id);

-- Seed built-in activity types (must match BuiltInActivity.ids in Swift)
insert into public.activity_types (id, name, symbol_name, sort_order, is_built_in, user_id) values
  ('a1000001-0000-0000-0000-000000000001', 'Meditation', 'brain.head.profile', 0, true, null),
  ('a1000002-0000-0000-0000-000000000002', 'Yoga', 'figure.yoga', 1, true, null),
  ('a1000003-0000-0000-0000-000000000003', 'Walking', 'figure.walk', 2, true, null),
  ('a1000004-0000-0000-0000-000000000004', 'Running', 'figure.run', 3, true, null),
  ('a1000005-0000-0000-0000-000000000005', 'Work', 'briefcase.fill', 4, true, null),
  ('a1000006-0000-0000-0000-000000000006', 'Cooking', 'frying.pan.fill', 5, true, null),
  ('a1000007-0000-0000-0000-000000000007', 'Reading', 'book.fill', 6, true, null),
  ('a1000008-0000-0000-0000-000000000008', 'Family', 'heart.fill', 7, true, null),
  ('a1000009-0000-0000-0000-000000000009', 'Study', 'book.closed.fill', 8, true, null)
on conflict (id) do nothing;
