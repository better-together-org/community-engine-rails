# AGENTS.md

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
- Use `DATABASE_URL` to connect (overrides fallback host in database.yml).

## Commands
- Run tests: `bin/ci`  
  (Equivalent: `cd spec/dummy && bundle exec rspec`)
- Lint: `bundle exec rubocop`
- Security: `bundle exec brakeman -q -w2` and `bundle exec bundler-audit --update`

## Conventions
- Make incremental changes with passing tests.
- Avoid introducing new external services in tests; stub where possible.

## Code Style
- Always run `bin/codex_style_guard` before proposing a patch.
- If RuboCop reports offenses after autocorrect, update the changes until it passes.
