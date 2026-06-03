-- ============================================================================
-- Crew App — Supabase migrations for Job 2 features
-- ----------------------------------------------------------------------------
-- Run these in the Supabase SQL editor. They are written idempotently
-- (IF NOT EXISTS) so they are safe to re-run.
--
-- The schema was reconstructed from in-code queries; adjust types/RLS to match
-- your existing tables where needed.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. CHAT — table is "chat_messages" (already created + added to the
--    supabase_realtime publication per project setup). Included here for
--    completeness / fresh environments.
-- ----------------------------------------------------------------------------
create table if not exists public.chat_messages (
  id         uuid primary key default gen_random_uuid(),
  match_id   uuid not null references public.matches(id) on delete cascade,
  sender_id  uuid not null references auth.users(id) on delete cascade,
  content    text not null,
  sent_at    timestamptz not null default now(),
  read_at    timestamptz
);
create index if not exists chat_messages_match_id_idx
  on public.chat_messages(match_id, sent_at);

-- Realtime (already enabled in this project; harmless to re-run):
-- alter publication supabase_realtime add table public.chat_messages;


-- ----------------------------------------------------------------------------
-- 2. PROFILES — new columns
--      availability_status : 'available_now' | 'available_soon' | 'unavailable'
--      fcm_token           : device push token for FCM
-- ----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists availability_status text;

alter table public.profiles
  add column if not exists fcm_token text;


-- ----------------------------------------------------------------------------
-- 3. ENDORSEMENTS
-- ----------------------------------------------------------------------------
create table if not exists public.endorsements (
  id           uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references auth.users(id) on delete cascade,
  to_user_id   uuid not null references auth.users(id) on delete cascade,
  match_id     uuid references public.matches(id) on delete set null,
  content      text not null,
  created_at   timestamptz not null default now()
);
create index if not exists endorsements_to_user_idx
  on public.endorsements(to_user_id);


-- ----------------------------------------------------------------------------
-- 4. RATINGS (1-5 stars). One rating per (rater, match).
-- ----------------------------------------------------------------------------
create table if not exists public.ratings (
  id           uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references auth.users(id) on delete cascade,
  to_user_id   uuid not null references auth.users(id) on delete cascade,
  match_id     uuid references public.matches(id) on delete set null,
  score        int  not null check (score between 1 and 5),
  created_at   timestamptz not null default now(),
  unique (from_user_id, match_id)
);
create index if not exists ratings_to_user_idx
  on public.ratings(to_user_id);


-- ----------------------------------------------------------------------------
-- 5. Row Level Security (recommended). Enable + add owner-scoped policies.
--    These are starter policies; tighten to your needs.
-- ----------------------------------------------------------------------------
alter table public.chat_messages enable row level security;
alter table public.endorsements  enable row level security;
alter table public.ratings       enable row level security;

-- chat_messages: a participant of the match can read; sender can insert.
drop policy if exists chat_messages_select on public.chat_messages;
create policy chat_messages_select on public.chat_messages
  for select using (
    exists (
      select 1 from public.matches m
      where m.id = chat_messages.match_id
        and (m.journeyman_id = auth.uid() or m.helper_id = auth.uid())
    )
  );

drop policy if exists chat_messages_insert on public.chat_messages;
create policy chat_messages_insert on public.chat_messages
  for insert with check (sender_id = auth.uid());

-- endorsements: anyone authenticated can read; only the author can write.
drop policy if exists endorsements_select on public.endorsements;
create policy endorsements_select on public.endorsements
  for select using (auth.role() = 'authenticated');

drop policy if exists endorsements_insert on public.endorsements;
create policy endorsements_insert on public.endorsements
  for insert with check (from_user_id = auth.uid());

-- ratings: anyone authenticated can read (for averages); only author can write.
drop policy if exists ratings_select on public.ratings;
create policy ratings_select on public.ratings
  for select using (auth.role() = 'authenticated');

drop policy if exists ratings_insert on public.ratings;
create policy ratings_insert on public.ratings
  for insert with check (from_user_id = auth.uid());
