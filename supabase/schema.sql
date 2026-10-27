-- Run in Supabase SQL Editor. Requires pgcrypto and vector extensions.
create extension if not exists pgcrypto;
create extension if not exists vector;

create type public.content_language as enum ('en', 'kn');
create type public.bookmark_target as enum ('article', 'question', 'document');

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  preferred_language public.content_language not null default 'en',
  target_exam text not null default 'KEA',
  daily_question_target integer not null default 20 check (daily_question_target between 1 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]{2,60}$'),
  name_en text not null,
  name_kn text not null,
  module text not null check (module in ('current_affairs','syllabus','exam')),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.current_affairs_articles (
  id uuid primary key default gen_random_uuid(),
  canonical_url text not null unique,
  source_name text not null,
  source_domain text not null,
  title text not null,
  title_kn text,
  summary_en text not null,
  summary_kn text,
  body_excerpt text,
  category_id uuid references public.categories(id) on delete set null,
  tags text[] not null default '{}',
  region text not null default 'india' check (region in ('india','karnataka','international')),
  language text,
  published_at timestamptz not null,
  fetched_at timestamptz not null default now(),
  digest_date date not null default (timezone('Asia/Kolkata', now()))::date,
  content_hash text not null,
  review_status text not null default 'pending' check (review_status in ('pending','approved','rejected')),
  provider_metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  check (canonical_url ~ '^https?://')
);
create index if not exists ca_published_idx on public.current_affairs_articles (published_at desc);
create index if not exists ca_region_date_idx on public.current_affairs_articles (region, digest_date desc);
create index if not exists ca_category_idx on public.current_affairs_articles (category_id);
create index if not exists ca_tags_idx on public.current_affairs_articles using gin(tags);
create index if not exists ca_search_idx on public.current_affairs_articles using gin (
  to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(summary_en,'') || ' ' || coalesce(body_excerpt,''))
);

create table if not exists public.study_materials (
  id uuid primary key default gen_random_uuid(),
  category_slug text not null check (category_slug in (
    'polity','karnataka-history','geography','science-tech','environment','computer-knowledge'
  )),
  title_en text not null,
  title_kn text,
  content_en text not null,
  content_kn text,
  source_url text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (source_url is null or source_url ~ '^https?://')
);
create index if not exists study_materials_module_idx
  on public.study_materials(category_slug, updated_at desc)
  where is_published = true;

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id) on delete set null,
  article_id uuid references public.current_affairs_articles(id) on delete cascade,
  question_en text not null,
  question_kn text,
  options_en jsonb not null check (jsonb_typeof(options_en) = 'array' and jsonb_array_length(options_en) = 4),
  options_kn jsonb check (options_kn is null or (jsonb_typeof(options_kn) = 'array' and jsonb_array_length(options_kn) = 4)),
  correct_option smallint not null check (correct_option between 0 and 3),
  explanation_en text not null,
  explanation_kn text,
  difficulty text not null default 'medium' check (difficulty in ('easy','medium','hard')),
  exam_tags text[] not null default '{}',
  source_url text,
  question_date date,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists questions_category_idx on public.questions(category_id);
create index if not exists questions_published_date_idx on public.questions(is_published, question_date desc);
create index if not exists questions_exam_tags_idx on public.questions using gin(exam_tags);

create table if not exists public.mock_tests (
  id uuid primary key default gen_random_uuid(),
  title_en text not null,
  title_kn text,
  exam_code text not null,
  description_en text,
  description_kn text,
  duration_seconds integer not null check (duration_seconds between 60 and 86400),
  total_questions integer not null check (total_questions between 1 and 1000),
  marks_per_correct numeric(6,2) not null default 1 check (marks_per_correct >= 0),
  marks_per_wrong numeric(6,2) not null default 0 check (marks_per_wrong <= 0),
  blueprint jsonb not null default '{}',
  is_published boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.mock_test_questions (
  mock_test_id uuid not null references public.mock_tests(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete restrict,
  position integer not null check (position > 0),
  primary key (mock_test_id, question_id),
  unique (mock_test_id, position)
);

create table if not exists public.test_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mock_test_id uuid references public.mock_tests(id) on delete set null,
  mode text not null default 'mock' check (mode in ('mock','daily_quiz','practice')),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  total_questions integer not null default 0 check (total_questions >= 0),
  correct_count integer not null default 0 check (correct_count >= 0),
  wrong_count integer not null default 0 check (wrong_count >= 0),
  skipped_count integer not null default 0 check (skipped_count >= 0),
  score numeric(10,2) not null default 0,
  max_score numeric(10,2) not null default 0,
  subject_breakdown jsonb not null default '{}',
  status text not null default 'in_progress' check (status in ('in_progress','submitted','expired')),
  created_at timestamptz not null default now()
);
create index if not exists attempts_user_time_idx on public.test_attempts(user_id, started_at desc);

create table if not exists public.test_attempt_answers (
  attempt_id uuid not null references public.test_attempts(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete restrict,
  selected_option smallint check (selected_option between 0 and 3),
  is_correct boolean,
  marks_awarded numeric(10,2) not null default 0,
  time_spent_seconds integer not null default 0 check (time_spent_seconds >= 0),
  marked_for_review boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (attempt_id, question_id)
);

create table if not exists public.user_bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  target_type public.bookmark_target not null,
  article_id uuid references public.current_affairs_articles(id) on delete cascade,
  question_id uuid references public.questions(id) on delete cascade,
  document_id uuid,
  note text,
  created_at timestamptz not null default now(),
  unique(user_id, article_id),
  unique(user_id, question_id),
  check (
    (target_type = 'article' and article_id is not null and question_id is null and document_id is null) or
    (target_type = 'question' and question_id is not null and article_id is null and document_id is null) or
    (target_type = 'document' and document_id is not null and article_id is null and question_id is null)
  )
);
create index if not exists bookmarks_user_time_idx on public.user_bookmarks(user_id, created_at desc);

create table if not exists public.study_documents (
  id uuid primary key default gen_random_uuid(),
  title_en text not null,
  title_kn text,
  exam_tags text[] not null default '{}',
  subject_slug text not null,
  source_url text,
  storage_path text,
  document_type text not null check (document_type in ('syllabus','pyq','gazette','budget','notes','other')),
  language public.content_language not null default 'en',
  published_date date,
  checksum text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);
alter table public.user_bookmarks drop constraint if exists user_bookmarks_document_id_fkey;
alter table public.user_bookmarks add constraint user_bookmarks_document_id_fkey
  foreign key (document_id) references public.study_documents(id) on delete cascade;

create table if not exists public.document_chunks (
  id bigserial primary key,
  document_id uuid not null references public.study_documents(id) on delete cascade,
  chunk_index integer not null check (chunk_index >= 0),
  content text not null,
  language public.content_language not null default 'en',
  embedding vector(1536),
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  unique(document_id, chunk_index)
);
create index if not exists document_chunks_embedding_idx
  on public.document_chunks using hnsw (embedding vector_cosine_ops)
  where embedding is not null;

create table if not exists public.daily_digests (
  id uuid primary key default gen_random_uuid(),
  digest_date date not null,
  language public.content_language not null,
  headline text not null,
  body text not null,
  article_ids uuid[] not null default '{}',
  quiz_question_ids uuid[] not null default '{}',
  generated_at timestamptz not null default now(),
  unique(digest_date, language)
);

-- Bootstrap categories (safe to rerun).
insert into public.categories(slug,name_en,name_kn,module,sort_order) values
 ('state-schemes','State Schemes','ರಾಜ್ಯ ಯೋಜನೆಗಳು','current_affairs',1),
 ('national-news','National News','ರಾಷ್ಟ್ರೀಯ ಸುದ್ದಿಗಳು','current_affairs',2),
 ('environment','Environment','ಪರಿಸರ','current_affairs',3),
 ('awards','Awards','ಪ್ರಶಸ್ತಿಗಳು','current_affairs',4),
 ('sports','Sports','ಕ್ರೀಡೆಗಳು','current_affairs',5),
 ('karnataka-history','Karnataka History','ಕರ್ನಾಟಕ ಇತಿಹಾಸ','syllabus',10),
 ('karnataka-geography','Karnataka Geography','ಕರ್ನಾಟಕ ಭೂಗೋಳ','syllabus',11),
 ('polity','Indian Polity & Governance','ಭಾರತೀಯ ರಾಜ್ಯಶಾಸ್ತ್ರ ಮತ್ತು ಆಡಳಿತ','syllabus',12),
 ('economy','Economy & Budget','ಅರ್ಥಶಾಸ್ತ್ರ ಮತ್ತು ಬಜೆಟ್','syllabus',13),
 ('science-tech','General Science & Technology','ಸಾಮಾನ್ಯ ವಿಜ್ಞಾನ ಮತ್ತು ತಂತ್ರಜ್ಞಾನ','syllabus',14),
 ('ecology','Ecology & Environment','ಪರಿಸರ ವಿಜ್ಞಾನ','syllabus',15),
 ('computer-knowledge','Computer Knowledge','ಕಂಪ್ಯೂಟರ್ ಜ್ಞಾನ','syllabus',16)
on conflict (slug) do update set name_en=excluded.name_en,name_kn=excluded.name_kn,module=excluded.module,sort_order=excluded.sort_order;

-- RLS: public study content is readable only when published/approved.
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.current_affairs_articles enable row level security;\nalter table public.study_materials enable row level security;
alter table public.questions enable row level security;
alter table public.mock_tests enable row level security;
alter table public.mock_test_questions enable row level security;
alter table public.test_attempts enable row level security;
alter table public.test_attempt_answers enable row level security;
alter table public.user_bookmarks enable row level security;
alter table public.study_documents enable row level security;
alter table public.document_chunks enable row level security;
alter table public.daily_digests enable row level security;

drop policy if exists "profile read own" on public.profiles;
create policy "profile read own" on public.profiles for select to authenticated using (id = auth.uid());
drop policy if exists "profile update own" on public.profiles;
create policy "profile update own" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists "categories readable" on public.categories;
create policy "categories readable" on public.categories for select to anon, authenticated using (true);
drop policy if exists "approved articles readable" on public.current_affairs_articles;
create policy "approved articles readable" on public.current_affairs_articles for select to anon, authenticated using (review_status = 'approved');
drop policy if exists "published study materials readable" on public.study_materials;
create policy "published study materials readable" on public.study_materials
  for select to anon, authenticated using (is_published = true);
drop policy if exists "published questions readable" on public.questions;
create policy "published questions readable" on public.questions for select to anon, authenticated using (is_published = true);
drop policy if exists "published tests readable" on public.mock_tests;
create policy "published tests readable" on public.mock_tests for select to anon, authenticated using (is_published = true);
drop policy if exists "test question links readable" on public.mock_test_questions;
create policy "test question links readable" on public.mock_test_questions for select to anon, authenticated using (
 exists (select 1 from public.mock_tests mt where mt.id = mock_test_id and mt.is_published = true)
);
drop policy if exists "attempts owner select" on public.test_attempts;
create policy "attempts owner select" on public.test_attempts for select to authenticated using (user_id = auth.uid());
drop policy if exists "attempts owner insert" on public.test_attempts;
create policy "attempts owner insert" on public.test_attempts for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "attempts owner update" on public.test_attempts;
create policy "attempts owner update" on public.test_attempts for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "answers own attempt" on public.test_attempt_answers;
create policy "answers own attempt" on public.test_attempt_answers for all to authenticated using (
 exists (select 1 from public.test_attempts a where a.id = attempt_id and a.user_id = auth.uid())
) with check (
 exists (select 1 from public.test_attempts a where a.id = attempt_id and a.user_id = auth.uid())
);
drop policy if exists "bookmarks owner all" on public.user_bookmarks;
create policy "bookmarks owner all" on public.user_bookmarks for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "study docs readable" on public.study_documents;
create policy "study docs readable" on public.study_documents for select to anon, authenticated using (true);
drop policy if exists "chunks readable" on public.document_chunks;
create policy "chunks readable" on public.document_chunks for select to anon, authenticated using (true);
drop policy if exists "daily digest readable" on public.daily_digests;
create policy "daily digest readable" on public.daily_digests for select to anon, authenticated using (true);

-- Create a profile automatically on signup.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)))
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();
