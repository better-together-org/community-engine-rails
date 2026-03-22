---
applyTo: "**/*.rb"
---
# Rails (7.1+) & Engine Conventions

## Framework & Structure
- Engine code is isolated under the `BetterTogether` namespace.
- Host apps may override/extend engine components; keep overrides minimal and well‑documented.
- Use PostgreSQL (with pgcrypto & PostGIS) in all envs.
- Prefer explicit join models over polymorphic when validations/foreign keys matter.
- Use `ENV.fetch` instead of `ENV[]`.

## Controllers
- Thin controllers: HTTP concerns only. Push business logic to POROs/services.
- Enforce authorization (e.g., Pundit/Policies) on every action and UI entry point.
- Respond with HTML/Turbo Stream/JSON as needed.

## Models
- Validate everything that can be validated.
- Minimize callbacks; prefer service objects & transactions.
- Add scopes returning `ActiveRecord::Relation`.
- Use AR Encryption for sensitive columns.

## Jobs (Sidekiq)
- Inherit from `ApplicationJob`; set `queue_as`.
- Idempotent by design; configure `retry_on`/`discard_on`.
- Group metrics jobs under `:metrics`, mailers under `:mailers`, etc.

## Internationalization
- All user strings must be translatable (`I18n` + `Mobility` for attributes).
- Never hard-code copy in code—use translation keys.
- Send emails and notifications in the recipient’s locale.

## Search (Elasticsearch)
- Keep `as_indexed_json` lean but complete (include translated/plaintext rich text).
- Trigger reindex jobs on relevant changes (after_commit).

## Security & Privacy
- Encrypt sensitive fields (AR Encryption); encrypt blobs via Active Storage.
- CSP: use nonces for inline JS.
- Never log secrets or PII; scrub logs.

## Testing
- Follow the project’s test framework (RSpec or Minitest); add system tests for Turbo flows.
