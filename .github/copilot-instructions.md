# Better Together Community Engine – Rails App & Engine Guidelines

This repository contains the **Better Together Community Engine** (an isolated Rails engine under the `BetterTogether` namespace) and/or a host Rails app that mounts it. Use these instructions for all code generation.

## Core Principles

- **Accessibility first** (WCAG AA/AAA): semantic HTML, ARIA roles, keyboard nav, proper contrast.
- **Hotwire everywhere**: Turbo for navigation/updates; Stimulus controllers for interactivity.
- **Keep controllers thin**; move business logic to POROs/service objects or concerns.
- **Prefer explicit join models** over polymorphic associations when validation matters.
- **Avoid the term “STI”** in code/comments; use “single-table inheritance” or alternate designs.
- **Use `ENV.fetch`** rather than `ENV[]`.
- **Always add policy/authorization checks** on links/buttons to controller actions.
- **i18n & Mobility**: every user-facing string must be translatable; include missing keys.

## Technology Stack

- **Rails 7.1+** (engine & current hosts) – compatible with Rails 8 targets
- **Ruby 3.3+**
- **PostgreSQL (+ PostGIS, pgcrypto)**
- **Redis** for caching & Sidekiq queues
- **Sidekiq** for background jobs (queue namespaced, e.g. `:metrics`)
- **Hotwire (Turbo, Stimulus)**
- **Bootstrap 5.3 & Font Awesome 6** (not Tailwind)
- **Trix / Action Text** for rich text
- **Active Record Encryption** for sensitive fields; encrypted Active Storage files
- **Mobility** for attribute translations
- **Elasticsearch 7** via `elasticsearch-rails`
- **Importmap-Rails** for JS deps (no bundler by default)
- **Dokku** (Docker-based PaaS) for deployment; Cloudflare for DNS/DDoS/tunnels
- **AWS S3 / MinIO** for file storage (transitioning to self-hosted MinIO)
- **Action Mailer + locale-aware emails**
- **Noticed** for notifications

> Dev DB: PostgreSQL (not SQLite). Production: PostgreSQL. PostGIS enabled for geospatial needs.

## Coding Guidelines

- **Ruby/Rails**
  - 2-space indent, snake_case methods, Rails conventions
  - Service objects in `app/services/`
  - Concerns for reusable model/controller logic
  - Strong params, Pundit/Policy checks (or equivalent) everywhere
  - Avoid fat callbacks; keep models lean
- **Views**
  - ERB with semantic HTML
  - Bootstrap utility classes; respect prefers-reduced-motion & other a11y prefs
  - Avoid inline JS; use Stimulus
  - External links in `.trix-content` get FA external-link icon unless internal/mailto/tel/pdf
- **Hotwire**
  - Use Turbo Streams for CRUD updates
  - Stimulus controllers in `app/javascript/controllers/`
  - No direct DOM manipulation without Stimulus targets/actions
- **Background Jobs**
  - Sidekiq jobs under appropriate queues (`:default`, `:mailers`, `:metrics`, etc.)
  - Idempotent job design; handle retries
- **Search**
  - Update `as_indexed_json` to include translated/plain-text fields as needed
- **Encryption & Privacy**
  - Use AR encryption for sensitive columns
  - Ensure blobs are encrypted at rest
- **Testing**
  - RSpec (if present) or Minitest – follow existing test framework
  - System tests for Turbo flows where possible

## Project Architecture Notes

- Engine code is namespaced under `BetterTogether`.
- Host app extends/overrides engine components where needed.
- Content blocks & page builder use configurable relationships (content areas, background images, etc.).
- Journey/Lists features use polymorphic items but with care (or explicit join models).
- Agreements system models participants, roles, terms, and timelines.

## Specialized Instruction Files

- `.github/instructions/rails_engine.instructions.md` – Engine isolation & namespacing
- `.github/instructions/hotwire.instructions.md` – Turbo/Stimulus patterns
- `.github/instructions/hotwire-native.instructions.md` – Hotwire Native patterns
- `.github/instructions/sidekiq-redis.instructions.md` – Background jobs & Redis
- `.github/instructions/search-elasticsearch.instructions.md` – Elasticsearch indexing patterns
- `.github/instructions/i18n-mobility.instructions.md` – Translations (Mobility + I18n)
- `.github/instructions/accessibility.instructions.md` – A11y checklist & patterns
- `.github/instructions/notifications-noticed.instructions.md` – Notification patterns
- `.github/instructions/deployment.instructions.md` – Dokku, Cloudflare, backups (S3/MinIO)
- `.github/instructions/security-encryption.instructions.md` – AR encryption, secrets
- `.github/instructions/bootstrap.instructions.md` – Styling, theming, icon usage
- `.github/instructions/importmaps.instructions.md` – JS dependency management
- `.github/instructions/view-helpers.instructions.md` – Consistency in Rails views

---

_If you generate code that touches any of these areas, consult the relevant instruction file and follow it._
