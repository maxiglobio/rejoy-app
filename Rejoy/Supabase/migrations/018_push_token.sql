-- Add push_token to profiles for remote push notifications (nudges, etc.)
-- Run in Supabase Dashboard → SQL Editor

alter table public.profiles add column if not exists push_token text;
