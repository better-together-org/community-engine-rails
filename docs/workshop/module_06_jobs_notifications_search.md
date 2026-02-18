# Module 06 — Jobs, Notifications, Search

Background processing with Sidekiq, user notifications with Noticed (Action Cable + Email), and Elasticsearch basics.

## Objectives
- Create and schedule robust background jobs
- Deliver localized notifications via Noticed (in‑app + email)
- Understand Elasticsearch indexing and querying basics
- Add tests for jobs, notifiers, and ES queries

## Topics
- Sidekiq workers, retries, idempotency, and logging
- Noticed notifications: channels, parameterized mailers, Action Cable feeds
- Elasticsearch lifecycle: indexing hooks, query patterns, health checks
- Observability: Sidekiq Web UI, logs, and failure triage

## Commands
- Jobs: use app logs and Sidekiq UI (`/sidekiq`) while authenticated as a platform manager
- Mailers: inspect logs/test delivery adapters
- ES health: curl or Rails console snippets if permitted in your environment

## Reading List
- `docs/developers/systems/notifications_system.md`
- Event reminder/update notifiers and jobs in the codebase
- `docs/developers/systems/*` search‑related docs (if present)

## Hands‑On Lab
- Lab 05 — Notifier + Job + ES Query — `./labs/lab_05_notifier_and_job_with_es_query.md`

