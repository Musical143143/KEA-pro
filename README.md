# KEA Pro — Flutter + Supabase + Python News Ingestion

A production-oriented foundation for Karnataka government-exam preparation. Includes:
- Flutter dashboard and timed quiz screen with English/Kannada UI labels
- Supabase PostgreSQL schema, indexes, RLS policies, and pgvector document chunks
- Python NewsAPI/GNews ingestion, OpenAI structured digest + 5-question quiz generation
- Deduplication, input validation, bounded retries/timeouts, idempotent daily run, structured logging
- GitHub Actions daily schedule and manual trigger

## Important deployment notes
This repository does not include API keys. Configure real secrets in the deployment environment; never commit `.env` or a Supabase service-role key. News API and LLM costs/terms vary. Verify article reuse rights and the latest official exam notification before configuring mock-test scoring. The included marking configuration is per-test data, not a claim that every KEA/KPSC exam uses the same rules.

## 1. Create Supabase
1. Create a Supabase project.
2. Open SQL Editor and run `supabase/schema.sql`.
3. Enable Email auth (or configure the auth providers you want).
4. Keep RLS enabled. The backend uses the service-role key and must run only in a trusted server environment.

## 2. Configure ingestion service
Python 3.11+ recommended.

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Fill in SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, OPENAI_API_KEY,
# and either NEWSAPI_KEY or GNEWS_API_KEY.
python -m keapro_ingest
```

Provider selection: NewsAPI is preferred if `NEWSAPI_KEY` is set; otherwise GNews is used if `GNEWS_API_KEY` is set. If neither is configured, the process exits with a clear configuration error. The service does not fabricate fallback articles.

Run daily using GitHub Actions. Add repository secrets:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `OPENAI_API_KEY`
- `NEWSAPI_KEY` or `GNEWS_API_KEY`

The workflow runs at 01:15 UTC (06:45 IST). You can also run it manually from Actions. The service is idempotent by canonical URL and publication date. It uses provider APIs rather than scraping publisher pages; only add RSS sources whose terms permit your intended use.

## 3. Configure Flutter app
Install Flutter stable and Android SDK, then:

```bash
cd mobile
flutter pub get
```

Create `mobile/lib/app_config.dart` from the example and set your Supabase project URL and **anon/publishable key**. Never put the service-role key in the mobile app.

```bash
flutter run
flutter test
flutter build apk --release
```

The app expects the schema in `supabase/schema.sql`. For production, configure Android signing, app links, crash reporting, accessibility checks, and privacy disclosures before release.

## 4. Current-affairs workflow
1. Fetch up to 100 recent articles from configured provider.
2. Validate title, URL, language, publication timestamp and content length.
3. Deduplicate by canonical URL.
4. Ask OpenAI for a concise bilingual digest, category, tags, source-faithful facts, and exactly five four-option MCQs.
5. Validate generated JSON (five questions, four options, valid answer index, explanations).
6. Insert article and quiz rows. Existing canonical URLs are skipped.

AI output is an aid, not an official answer key. Editorial review is recommended before using generated questions in high-stakes exam preparation.

## 5. Database model
- `profiles`: app profile linked to `auth.users`
- `categories`: controlled subject/category list
- `current_affairs_articles`: sourced article + bilingual summaries
- `questions`: practice and current-affairs questions
- `mock_tests`: test configuration, including negative marks
- `mock_test_questions`: ordered test-question join
- `test_attempts`: per-user attempt metadata and score
- `test_attempt_answers`: selected answers and correctness
- `user_bookmarks`: saved article/question/document
- `study_documents`, `document_chunks`: syllabus/PYQ metadata and pgvector chunks
- `daily_digests`: one digest per date/language

## 6. Production checklist
- Rotate secrets immediately if accidentally exposed.
- Configure provider quotas, request limits, and alerting.
- Add a moderation/editorial review state before publishing AI questions.
- Add an exam-specific verified blueprint for every exam; do not assume a universal marking rule.
- Add backup/restore drills, database migrations, privacy policy, account deletion, and monitoring.
- Never store API keys in Flutter, client-side code, Git history, or a public repository.
