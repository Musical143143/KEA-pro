-- KEA Pro core schema for Supabase SQL Editor.
-- Run as project owner. Keep RLS enabled; never put service_role keys in the app.

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  question_en text not null check (length(trim(question_en)) > 0),
  question_kn text,
  options_en jsonb not null check (jsonb_typeof(options_en) = 'array' and jsonb_array_length(options_en) >= 2),
  options_kn jsonb check (options_kn is null or (jsonb_typeof(options_kn) = 'array' and jsonb_array_length(options_kn) >= 2)),
  correct_option integer not null check (correct_option >= 0),
  explanation_en text,
  explanation_kn text,
  category text not null default 'General',
  difficulty text not null default 'medium' check (difficulty in ('easy','medium','hard')),
  source_name text,
  source_url text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint questions_correct_option_in_range check (correct_option < jsonb_array_length(options_en))
);

create table if not exists public.current_affairs_articles (
  id uuid primary key default gen_random_uuid(),
  title_en text not null check (length(trim(title_en)) > 0),
  title_kn text,
  summary_en text,
  summary_kn text,
  canonical_url text,
  source_name text not null default 'Unknown source',
  published_at timestamptz,
  region text not null default 'Karnataka' check (region in ('Karnataka','India','All India')),
  category text not null default 'General',
  tags text[] not null default '{}',
  review_status text not null default 'pending' check (review_status in ('pending','approved','rejected')),
  source_hash text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.study_materials (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('Polity & Governance','Karnataka History','Geography','Science & Tech','Environment','Computer Knowledge')),
  title_en text not null check (length(trim(title_en)) > 0),
  title_kn text,
  content_en text not null default '',
  content_kn text,
  source_url text,
  source_name text,
  sort_order integer not null default 0,
  is_published boolean not null default false,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.user_bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  article_id uuid not null references public.current_affairs_articles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, article_id)
);

create index if not exists questions_published_created_idx
  on public.questions (is_published, created_at desc);
create index if not exists articles_region_status_published_idx
  on public.current_affairs_articles (region, review_status, published_at desc);
create index if not exists articles_title_en_trgm_idx
  on public.current_affairs_articles using gin (title_en gin_trgm_ops);
create index if not exists study_materials_category_published_sort_idx
  on public.study_materials (category, is_published, sort_order, updated_at desc);
create index if not exists user_bookmarks_user_created_idx
  on public.user_bookmarks (user_id, created_at desc);

-- pg_trgm was enabled above so its operator class is available for the index.

alter table public.questions enable row level security;
alter table public.current_affairs_articles enable row level security;
alter table public.study_materials enable row level security;
alter table public.user_bookmarks enable row level security;

drop policy if exists "Published questions are readable" on public.questions;
create policy "Published questions are readable"
  on public.questions for select to anon, authenticated
  using (is_published = true);

drop policy if exists "Approved articles are readable" on public.current_affairs_articles;
create policy "Approved articles are readable"
  on public.current_affairs_articles for select to anon, authenticated
  using (review_status = 'approved');

drop policy if exists "Published study material is readable" on public.study_materials;
create policy "Published study material is readable"
  on public.study_materials for select to anon, authenticated
  using (is_published = true);

drop policy if exists "Users read own bookmarks" on public.user_bookmarks;
create policy "Users read own bookmarks"
  on public.user_bookmarks for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users add own bookmarks" on public.user_bookmarks;
create policy "Users add own bookmarks"
  on public.user_bookmarks for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own bookmarks" on public.user_bookmarks;
create policy "Users delete own bookmarks"
  on public.user_bookmarks for delete to authenticated
  using (auth.uid() = user_id);

grant select on public.questions to anon, authenticated;
grant select on public.current_affairs_articles to anon, authenticated;
grant select on public.study_materials to anon, authenticated;
grant select, insert, delete on public.user_bookmarks to authenticated;
