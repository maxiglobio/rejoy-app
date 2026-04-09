-- Altar feature flag: when true, Profile tab shows Profile/Altar switcher and altar editor.
-- RLS on public.profiles already allows users to update their own row.

alter table public.profiles
  add column if not exists altar_enabled boolean not null default false;

comment on column public.profiles.altar_enabled is 'User enabled Personal Altar from Settings; synced to app for Profile/Altar UI.';
