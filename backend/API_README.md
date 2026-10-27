# Ingestion API contract and operational details

The ingestion process is intentionally a scheduled worker, not an unauthenticated public endpoint. Run it from GitHub Actions or a private server. Never expose `SUPABASE_SERVICE_ROLE_KEY` to Flutter.

## Provider configuration
- NewsAPI: `NEWSAPI_KEY`
- GNews fallback: `GNEWS_API_KEY`
- AI: `OPENAI_API_KEY`, optional `OPENAI_MODEL`

NewsAPI's free tier may have delayed results and development-only restrictions. Production availability depends on the provider plan and terms. If both keys are set, NewsAPI is selected first. Provider outages produce a failed run rather than invented content.

## Review workflow
Default `PUBLISH_AI_CONTENT=false` stores articles as `pending` and questions as unpublished. Set true only after your editorial policy accepts AI-generated content without manual review. For a real production education app, use an admin review queue and record reviewer identity/time before publishing.

## Recommended additions before public launch
- Add an admin-only RPC/Edge Function to approve content; don't grant client updates to content tables.
- Add rate limiting and signed invocation for manual refresh.
- Use a queue for large imports, dead-letter records for repeated failures, and metrics/alerts.
- Use official documents for legal/constitutional material and preserve source citations in study content.
- Use an embedding model with the same dimension as `document_chunks.embedding` (1536 here); only insert embeddings from a matching model.
