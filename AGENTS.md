# AGENTS.md

Instructions for GitHub Copilot and other automated contributors working in this repository.

## Project
- Ruby: 3.4.4 (installed via rbenv in setup)
- Rails: 7.1
- Node: 20
- DB: PostgreSQL + PostGIS
- Search: Elasticsearch 7.17.23
- Test app: `spec/dummy`

## Setup
- Environment runs a setup script that installs Ruby 3.4.4, Node 20, Postgres + PostGIS, and ES7, then prepares databases.
- Databases:
  - development: `community_engine_development`
  - test: `community_engine_test`
- Use `DATABASE_URL` to connect (overrides fallback host in `config/database.yml`).

## Commands
- **Tests:** `bin/ci`
  (Equivalent: `cd spec/dummy && bundle exec rspec`)
- **Lint:** `bundle exec rubocop`
- **Security:** `bundle exec brakeman -q -w2` and `bundle exec bundler-audit --update`
- **Style:** `bin/codex_style_guard`

## Security Requirements
- **Always run Brakeman** before generating/committing code: `bundle exec brakeman -q`
- **Address high-confidence vulnerabilities immediately** - anything with "High" confidence must be fixed
- **Review medium-confidence warnings** - evaluate and fix security-relevant issues  
- **Use safe coding practices:**
  - Never use `constantize`, `safe_constantize`, or `eval` on user input
  - Use allow-lists for dynamic class resolution (see `joatu_source_class` pattern)
  - Sanitize and validate all user inputs
  - Use strong parameters in controllers
  - Implement proper authorization checks (Pundit policies)
- **For reflection-based code**: Create concern-based allow-lists using `included_in_models` pattern
- **Run security scan after major changes**: `bundle exec brakeman -c UnsafeReflection,SQL,CrossSiteScripting`

## Conventions
- Make incremental changes with passing tests.
- **Security first**: Run `bundle exec brakeman -q` before committing code changes.
- Avoid introducing new external services in tests; stub where possible.
- If RuboCop reports offenses after autocorrect, update and rerun until clean.
- Keep commit messages and PR descriptions concise and informative.

## Documentation & Diagrams
- Always update documentation when adding new functionality or changing data relationships.
  - For new features or flows: add/update a process doc under `docs/` that explains intent, actors, states, and key branch points.
  - For model/association changes: update Mermaid diagrams (e.g., `docs/*_diagram.mmd` or add a new one alongside related docs).
- Keep diagrams in Mermaid (`.mmd`) and render PNGs for convenience.
  - Preferred: run `bin/render_diagrams` to regenerate images for all `docs/*.mmd` files.
  - Fallback: `npx -y @mermaid-js/mermaid-cli -i docs/your_diagram.mmd -o docs/your_diagram.png`.
- PRs that add/modify models, associations, or flows must include corresponding docs and diagrams.
- When notifications, policies, or routes change, ensure affected docs and diagrams are updated to match behavior.

## Platform Registration Mode
- Invitation-required: Platforms support `requires_invitation` (see `BetterTogether::Platform#settings`). When enabled, users must supply a valid invitation code to register. This is the default for hosted deployments.
- Where to change: Host Dashboard → Platforms → Edit → “Requires Invitation”.
- Effects:
  - Devise registration page prompts for an invitation code when none is present.
  - Accepted invitations prefill email, apply community/platform roles, and are marked accepted on successful sign‑up.

## Privacy Practices for Hosts (Admin Ops)
- Default posture: keep `requires_invitation` enabled unless there is a clear, consented need to open registration.
- Privacy policy: publish and maintain a platform‑specific privacy policy; disclose any third‑party trackers (e.g., GA, Sentry) and their purposes.
- Consent/cookies: add a cookie/consent banner before enabling third‑party trackers; anonymize IPs; disable ad personalization; respect regional requirements.
- Data minimization:
  - Avoid placing PII in URLs, block identifiers, or public content.
  - Do not add user identifiers to metrics — the engine’s built‑in metrics are event‑only by design.
- Retention & deletion:
  - Define retention periods for metrics and exports (e.g., 90 days for CSV exports; 180 days for raw events).
  - Regularly purge report files (Active Storage) and delete old metrics in batches.
  - Honor data deletion requests: remove user content and related exports; avoid exporting PII.
- Environments: do not copy production data to development/staging; use seeded, synthetic content for testing.

## Translations & Locales
- All user‑facing text must use I18n — do not hard‑code strings in views, controllers, models, or JS.
- When adding new text, add translation keys for all available locales in this repo (e.g., `config/locales/en.yml`, `es.yml`, `fr.yml`).
- Include translations for:
  - Flash messages, validation errors, button/label text, email subjects/bodies, and Action Cable payloads.
  - Any UI strings rendered from background jobs or notifiers.
- Prefer existing keys where possible; group new keys under appropriate namespaces.
- If a locale is missing a translation at review time, translate the English copy rather than leaving it undefined.

# Translation Normalization & Coverage

We use the `i18n-tasks` gem to ensure all translation keys are present, normalized, and up-to-date across all supported locales (en, fr, es, etc.).

## Workflow
- Run `i18n-tasks normalize` to sort and format locale files.
- Run `i18n-tasks missing` to identify missing keys and add them in English first.
- Use `i18n-tasks add-missing` to auto-populate missing keys with English values, then translate as needed.
- Review and improve translation quality regularly.
- All new user-facing strings must be added to locale files and checked with `i18n-tasks` before merging.

## Example Commands
```bash
i18n-tasks normalize
i18n-tasks missing
i18n-tasks add-missing
i18n-tasks health
```

See `.github/instructions/i18n-mobility.instructions.md` for additional translation rules.
