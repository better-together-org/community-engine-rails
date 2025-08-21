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

## Conventions
- Make incremental changes with passing tests.
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
