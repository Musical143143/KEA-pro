"""Scheduled, idempotent KEA Pro current-affairs ingestion.

Uses real NewsAPI or GNews results, OpenAI JSON output, validation, and Supabase.
No fabricated articles are inserted. Keep PUBLISH_AI_CONTENT=false until editorial
review workflow is configured.
"""
from __future__ import annotations
import hashlib, json, logging, os, re, sys
from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse, urlunparse
from zoneinfo import ZoneInfo
import httpx
from pydantic import BaseModel, Field, ValidationError
from pydantic_settings import BaseSettings, SettingsConfigDict
from supabase import create_client, Client
from openai import OpenAI

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    newsapi_key: str = ""
    gnews_api_key: str = ""
    news_lookback_hours: int = Field(default=36, ge=1, le=168)
    max_articles_per_run: int = Field(default=50, ge=1, le=100)
    min_article_text_chars: int = Field(default=120, ge=50, le=10000)
    publish_ai_content: bool = False
    log_level: str = "INFO"

class MCQ(BaseModel):
    question_en: str = Field(min_length=10, max_length=600)
    question_kn: str = Field(min_length=5, max_length=900)
    options_en: list[str] = Field(min_length=4, max_length=4)
    options_kn: list[str] = Field(min_length=4, max_length=4)
    correct_option: int = Field(ge=0, le=3)
    explanation_en: str = Field(min_length=10, max_length=1600)
    explanation_kn: str = Field(min_length=5, max_length=2000)
    difficulty: str = "medium"

class Enrichment(BaseModel):
    title_kn: str = Field(min_length=3, max_length=400)
    summary_en: str = Field(min_length=40, max_length=1800)
    summary_kn: str = Field(min_length=30, max_length=2400)
    category_slug: str
    tags: list[str] = Field(min_length=1, max_length=8)
    region: str
    digest_headline_en: str = Field(min_length=8, max_length=180)
    digest_headline_kn: str = Field(min_length=5, max_length=240)
    quiz: list[MCQ] = Field(min_length=5, max_length=5)

CATEGORIES = {"state-schemes","national-news","environment","awards","sports",
              "karnataka-history","karnataka-geography","polity","economy",
              "science-tech","ecology","computer-knowledge"}
ALLOWED_REGIONS = {"india", "karnataka", "international"}
IST = ZoneInfo("Asia/Kolkata")

def required(value: str, name: str) -> str:
    if not value or value.startswith("put_") or "YOUR_PROJECT" in value:
        raise RuntimeError(f"Required configuration missing: {name}")
    return value

def canonical_url(raw: str) -> str:
    p = urlparse(raw.strip())
    if p.scheme not in ("http", "https") or not p.netloc:
        raise ValueError("Article URL must be absolute HTTP(S)")
    host = p.netloc.lower().removeprefix("www.")
    # Remove tracking query parameters; preserve meaningful article IDs.
    from urllib.parse import parse_qsl, urlencode
    q = [(k,v) for k,v in parse_qsl(p.query, keep_blank_values=True)
         if not k.lower().startswith("utm_") and k.lower() not in {"fbclid","gclid","ref"}]
    return urlunparse((p.scheme.lower(), host, p.path.rstrip("/") or "/", "", urlencode(q), ""))

def parse_datetime(value: str | None) -> datetime:
    if not value:
        return datetime.now(timezone.utc)
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)
    except ValueError:
        return datetime.now(timezone.utc)

def fetch_news(s: Settings) -> list[dict]:
    now = datetime.now(timezone.utc)
    since = now - timedelta(hours=s.news_lookback_hours)
    with httpx.Client(timeout=httpx.Timeout(20, connect=8), follow_redirects=True) as client:
        if s.newsapi_key:
            resp = client.get("https://newsapi.org/v2/everything", params={
                "q": '(Karnataka OR India) AND (government OR policy OR scheme OR economy OR environment OR science OR sports)',
                "from": since.date().isoformat(), "to": now.date().isoformat(),
                "language": "en", "sortBy": "publishedAt",
                "pageSize": min(s.max_articles_per_run, 100), "apiKey": s.newsapi_key})
            resp.raise_for_status()
            payload = resp.json()
            if payload.get("status") != "ok":
                raise RuntimeError("NewsAPI returned non-ok status")
            rows = payload.get("articles", [])
            return [{"title": a.get("title"), "url": a.get("url"),
                     "source": (a.get("source") or {}).get("name", "NewsAPI"),
                     "published": a.get("publishedAt"), "description": a.get("description") or "",
                     "content": a.get("content") or ""} for a in rows]
        if s.gnews_api_key:
            resp = client.get("https://gnews.io/api/v4/search", params={
                "q": "Karnataka OR India government scheme economy environment science sports",
                "from": since.isoformat(timespec="seconds"), "to": now.isoformat(timespec="seconds"),
                "lang": "en", "max": min(s.max_articles_per_run, 100), "apikey": s.gnews_api_key})
            resp.raise_for_status()
            rows = resp.json().get("articles", [])
            return [{"title": a.get("title"), "url": a.get("url"),
                     "source": (a.get("source") or {}).get("name", "GNews"),
                     "published": a.get("publishedAt"), "description": a.get("description") or "",
                     "content": a.get("content") or ""} for a in rows]
    raise RuntimeError("Set NEWSAPI_KEY or GNEWS_API_KEY; no demo feed is used.")

def enrich(openai_client: OpenAI, model: str, article: dict) -> Enrichment:
    material = "\n".join([
        "TITLE: " + article["title"],
        "PUBLISHED: " + article["published"],
        "DESCRIPTION: " + article["description"],
        "ARTICLE EXCERPT: " + article["content"][:5000],
        "SOURCE: " + article["source"],
        "URL: " + article["url"],
    ])
    schema = {
      "name":"kea_current_affairs_enrichment",
      "strict":True,
      "schema":{"type":"object","additionalProperties":False,"properties":{
        "title_kn":{"type":"string"},
        "summary_en":{"type":"string"},
        "summary_kn":{"type":"string"},
        "category_slug":{"type":"string","enum":sorted(CATEGORIES)},
        "tags":{"type":"array","items":{"type":"string"},"minItems":1,"maxItems":8},
        "region":{"type":"string","enum":["india","karnataka","international"]},
        "digest_headline_en":{"type":"string"},
        "digest_headline_kn":{"type":"string"},
        "quiz":{"type":"array","minItems":5,"maxItems":5,"items":{"type":"object","additionalProperties":False,"properties":{
          "question_en":{"type":"string"},"question_kn":{"type":"string"},
          "options_en":{"type":"array","items":{"type":"string"},"minItems":4,"maxItems":4},
          "options_kn":{"type":"array","items":{"type":"string"},"minItems":4,"maxItems":4},
          "correct_option":{"type":"integer","minimum":0,"maximum":3},
          "explanation_en":{"type":"string"},"explanation_kn":{"type":"string"},
          "difficulty":{"type":"string","enum":["easy","medium","hard"]}
        },"required":["question_en","question_kn","options_en","options_kn","correct_option","explanation_en","explanation_kn","difficulty"]}}
      },"required":["title_kn","summary_en","summary_kn","category_slug","tags","region","digest_headline_en","digest_headline_kn","quiz"]}}
    response = openai_client.chat.completions.create(
      model=model, temperature=0.2,
      response_format={"type":"json_schema","json_schema":schema},
      messages=[
        {"role":"system","content":
         "You create accurate bilingual Karnataka government-exam study material. Use only facts supported by the supplied source. Never invent dates, statistics, names or legal claims. If the source is insufficient for a reliable quiz, return a cautious question about only a supported fact. English and Kannada must both be natural. Exactly five MCQs; four distinct options; one unambiguous correct option; explanations grounded in source. Choose a relevant category and region."},
        {"role":"user","content":material}
      ],
      timeout=60
    )
    content = response.choices[0].message.content
    if not content:
        raise ValueError("LLM returned an empty response")
    data = Enrichment.model_validate_json(content)
    if data.category_slug not in CATEGORIES or data.region not in ALLOWED_REGIONS:
        raise ValueError("Generated category/region is invalid")
    for q in data.quiz:
        if len({x.strip().casefold() for x in q.options_en}) != 4:
            raise ValueError("Duplicate English options in generated question")
        if len({x.strip().casefold() for x in q.options_kn}) != 4:
            raise ValueError("Duplicate Kannada options in generated question")
    return data

def run() -> int:
    s = Settings()
    logging.basicConfig(level=getattr(logging, s.log_level.upper(), logging.INFO),
                        format="%(asctime)s %(levelname)s %(message)s")
    required(s.supabase_url, "SUPABASE_URL")
    required(s.supabase_service_role_key, "SUPABASE_SERVICE_ROLE_KEY")
    required(s.openai_api_key, "OPENAI_API_KEY")
    db: Client = create_client(s.supabase_url, s.supabase_service_role_key)
    ai = OpenAI(api_key=s.openai_api_key, timeout=60, max_retries=2)
    category_rows = db.table("categories").select("id,slug").execute().data or []
    category_ids = {r["slug"]: r["id"] for r in category_rows}
    articles = fetch_news(s)
    logging.info("Fetched %d provider records", len(articles))
    inserted = skipped = failed = 0
    today = datetime.now(IST).date().isoformat()
    digest_articles = []
    for raw in articles[:s.max_articles_per_run]:
        try:
            title = re.sub(r"\s+", " ", (raw.get("title") or "").strip())
            url = canonical_url(raw.get("url") or "")
            desc = re.sub(r"\s+", " ", (raw.get("description") or "").strip())
            body = re.sub(r"\s+", " ", (raw.get("content") or "").strip())
            if len(title) < 8 or not desc:
                skipped += 1
                continue
            exists = db.table("current_affairs_articles").select("id").eq("canonical_url", url).limit(1).execute().data
            if exists:
                skipped += 1
                continue
            source = str(raw.get("source") or "Unknown")[:160]
            published = parse_datetime(raw.get("published")).isoformat()
            generated = enrich(ai, s.openai_model, {
                "title": title, "url": url, "source": source,
                "published": published, "description": desc, "content": body})
            domain = urlparse(url).netloc
            digest_date = parse_datetime(published).astimezone(IST).date().isoformat()
            content_hash = hashlib.sha256((title + url + desc).encode()).hexdigest()
            article_row = {
                "canonical_url":url, "source_name":source, "source_domain":domain,
                "title":title, "title_kn":generated.title_kn,
                "summary_en":generated.summary_en, "summary_kn":generated.summary_kn,
                "body_excerpt":(body or desc)[:4000], "category_id":category_ids.get(generated.category_slug),
                "tags":[re.sub(r"[^a-zA-Z0-9 -]","",t).strip().lower()[:40] for t in generated.tags],
                "region":generated.region, "language":"en", "published_at":published,
                "digest_date":digest_date, "content_hash":content_hash,
                "review_status":"approved" if s.publish_ai_content else "pending",
                "provider_metadata":{"provider":"newsapi" if s.newsapi_key else "gnews"}
            }
            inserted_row = db.table("current_affairs_articles").insert(article_row).execute().data
            if not inserted_row:
                raise RuntimeError("Database did not return inserted article")
            article_id = inserted_row[0]["id"]
            digest_articles.append({"id":article_id,"headline_en":generated.digest_headline_en,
                                    "headline_kn":generated.digest_headline_kn,
                                    "summary_en":generated.summary_en,"summary_kn":generated.summary_kn})
            question_rows = []
            for q in generated.quiz:
                question_rows.append({
                  "category_id":category_ids.get(generated.category_slug),"article_id":article_id,
                  "question_en":q.question_en,"question_kn":q.question_kn,
                  "options_en":q.options_en,"options_kn":q.options_kn,
                  "correct_option":q.correct_option,"explanation_en":q.explanation_en,
                  "explanation_kn":q.explanation_kn,"difficulty":q.difficulty,
                  "exam_tags":["KEA","KPSC","VA","FDA","SDA","PSI","PDO"],
                  "source_url":url,"question_date":digest_date,"is_published":s.publish_ai_content
                })
            db.table("questions").insert(question_rows).execute()
            inserted += 1
            logging.info("Inserted article %s (%s)", article_id, url)
        except (httpx.HTTPError, ValidationError, ValueError, RuntimeError) as exc:
            failed += 1
            logging.exception("Skipping invalid/failed article: %s", exc)
        except Exception:
            failed += 1
            logging.exception("Unexpected ingestion failure")
    if digest_articles:
        # Store compact digest data in both languages; article content remains linked.
        for lang, title_key, summary_key in [
            ("en","headline_en","summary_en"),("kn","headline_kn","summary_kn")]:
            headlines = [x[title_key] for x in digest_articles[:12]]
            summaries = [x[summary_key] for x in digest_articles[:12]]
            db.table("daily_digests").upsert({
              "digest_date":today,"language":lang,
              "headline":"Daily KEA Pro Current Affairs" if lang=="en" else "ದೈನಂದಿನ KEA ಪ್ರೊ ಪ್ರಚಲಿತ ವಿದ್ಯಮಾನಗಳು",
              "body":"\n\n".join(f"• {h}\n{s}" for h,s in zip(headlines,summaries)),
              "article_ids":[x["id"] for x in digest_articles],
              "quiz_question_ids":[]
            },on_conflict="digest_date,language").execute()
    logging.info("Run complete: inserted=%d skipped=%d failed=%d",inserted,skipped,failed)
    return 1 if failed and not inserted else 0

if __name__ == "__main__":
    try:
        sys.exit(run())
    except Exception as exc:
        logging.basicConfig(level=logging.INFO)
        logging.exception("Fatal ingestion error: %s", exc)
        sys.exit(1)
