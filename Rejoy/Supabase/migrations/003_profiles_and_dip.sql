-- Rejoy: Profiles table for DIP plan and teacher portrait
-- Run after 002_achievements.sql

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  plan_type text not null default 'free' check (plan_type in ('free', 'dip')),
  teacher_portrait_url text,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- Storage bucket for teacher portraits: create via Supabase Dashboard → Storage
-- Bucket name: teacher-portraits
-- RLS: users can upload/update/delete only their own file (path: {userId}.jpg)
