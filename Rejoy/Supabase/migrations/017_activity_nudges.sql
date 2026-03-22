-- Activity nudges: "push to activity" from one sangha member to another
-- Run in Supabase Dashboard → SQL Editor

create table if not exists public.activity_nudges (
  id uuid primary key default gen_random_uuid(),
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  receiver_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  seen_at timestamptz
);

-- Index for fast lookups by receiver
create index if not exists activity_nudges_receiver_user_id_idx on public.activity_nudges(receiver_user_id);

-- Enable RLS
alter table public.activity_nudges enable row level security;

-- SELECT: Users can read nudges where they are the receiver
create policy "Users can read own received nudges"
  on public.activity_nudges for select
  using (receiver_user_id = auth.uid());

-- INSERT: Users can insert only when sender_user_id = auth.uid() and they share a sangha with the receiver
create policy "Users can insert nudge for sangha members"
  on public.activity_nudges for insert
  with check (
    sender_user_id = auth.uid()
    and receiver_user_id != auth.uid()
    and exists (
      select 1 from sangha_members sm1
      join sangha_members sm2 on sm1.sangha_id = sm2.sangha_id and sm2.is_visible = true
      where sm1.user_id = auth.uid()
        and sm2.user_id = receiver_user_id
    )
  );

-- UPDATE: Users can update only their own received nudges (to set seen_at)
create policy "Users can update own received nudges"
  on public.activity_nudges for update
  using (receiver_user_id = auth.uid());
