---
applyTo: "**/*job.rb,**/sidekiq*.rb,**/redis*.rb,**/initializers/*.rb"
---
# Sidekiq & Redis Guidelines

## Configuration
- Use Redis for: Sidekiq queues, caching, and ActionCable (if used).
- Define queues by purpose: `default`, `mailers`, `metrics`, etc.
- Match Sidekiq concurrency to DB pool size (threads ≤ pool_size - 2).

## Jobs
- Idempotent perform blocks (safe to retry).
- Use `retry_on` with specific exceptions; `discard_on` for expected failures.
- Tag jobs with `sidekiq_options queue: :metrics, backtrace: true` when helpful.

## Monitoring & Metrics
- Expose Sidekiq Web UI behind authentication.
- Track failures (`Sidekiq::DeadSet`) and clear or alert accordingly.

## Caching with Redis
- Use Rails.cache with Redis store; set sensible expiries.
- Avoid giant keys/blobs; namespace keys.
