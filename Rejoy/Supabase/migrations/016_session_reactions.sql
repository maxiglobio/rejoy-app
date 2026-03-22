-- Session reactions: smile/like on finished activities (member details page)
-- Run in Supabase Dashboard → SQL Editor

create table if not exists public.session_reactions (
  session_id uuid not null references public.sessions(id) on delete cascade,
  reactor_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (session_id, reactor_user_id)
);

-- Index for fast lookups by session
create index if not exists session_reactions_session_id_idx on public.session_reactions(session_id);

-- Enable RLS
alter table public.session_reactions enable row level security;

-- SELECT: Users can read reactions for sessions they can read (own or visible sangha members)
create policy "Users can read reactions for visible sessions"
  on public.session_reactions for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = session_reactions.session_id
        and (
          s.user_id = auth.uid()
          or exists (
            select 1 from sangha_members sm1
            join sangha_members sm2 on sm1.sangha_id = sm2.sangha_id and sm2.is_visible = true
            where sm1.user_id = auth.uid()
              and sm2.user_id = s.user_id
          )
        )
    )
  );

-- INSERT: Users can insert their own reaction only for sessions they can read
create policy "Users can insert own reaction for visible sessions"
  on public.session_reactions for insert
  with check (
    reactor_user_id = auth.uid()
    and exists (
      select 1 from public.sessions s
      where s.id = session_reactions.session_id
        and (
          s.user_id = auth.uid()
          or exists (
            select 1 from sangha_members sm1
            join sangha_members sm2 on sm1.sangha_id = sm2.sangha_id and sm2.is_visible = true
            where sm1.user_id = auth.uid()
              and sm2.user_id = s.user_id
          )
        )
    )
  );
