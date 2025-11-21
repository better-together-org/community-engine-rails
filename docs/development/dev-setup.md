# Development Setup

**Purpose:** Quick-start guide for contributors to run the Community Engine locally with the documented Docker tooling.

## Prerequisites
- Docker Engine running (all DB-dependent commands must use `bin/dc-run`)
- Ruby 3.4.4 (managed by `rbenv` in the setup scripts)
- Node 20

## Initial Setup
1. **Install dependencies**  
   Run the repository setup script (bundler, yarn, PostgreSQL + PostGIS, Elasticsearch).
2. **Prepare databases**  
   Use the provided Docker helpers to ensure commands run inside the containers:
   - `bin/dc-run bundle exec rails db:prepare`
   - `bin/dc-run bundle exec rails db:seed` (if needed)
3. **Verify test application**  
   Run the dummy app specs:  
   `bin/dc-run bin/ci`

## Everyday Commands
- **Tests:** `bin/dc-run bin/ci` or target files with `bin/dc-run bundle exec rspec spec/path_spec.rb`
- **Lint:** `bin/dc-run bundle exec rubocop`
- **I18n checks:** `bin/dc-run bin/i18n`
- **Brakeman security scan:** `bin/dc-run bundle exec brakeman --quiet --no-pager`

## Notes
- Avoid using Rails console for debugging; prefer writing or refining tests.
- Keep Docker running; database and Elasticsearch services are provided by the compose environment.
- Use `bin/dc-run-dummy` for commands that must run in the dummy app context.
