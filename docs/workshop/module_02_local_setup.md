# Module 02 — Local Setup (Docker)

This module sets up the local environment, runs smoke tests, and covers required run patterns.

## Objectives
- Start the full stack using project scripts
- Run tests, linting, and i18n tooling
- Know when to use `bin/dc-run` vs `bin/dc-run-dummy`

## Steps
1. Verify prerequisites from the Preflight Checklist
2. Start services: `./bin/dc-up` (and `./bin/dc-restart` as needed)
3. Run tests: `bin/dc-run bin/ci`
4. Lint: `bin/dc-run bundle exec rubocop`
5. Security: `bin/dc-run bundle exec brakeman --quiet --no-pager`
6. i18n: `bin/dc-run bin/i18n all`
7. Open the app, confirm home page loads

## Patterns
- Always wrap service-dependent commands with `bin/dc-run`
- Use `bin/dc-run-dummy` for dummy app Rails commands (migrations/console in test app)
- Prefer request specs; avoid controller specs unless necessary

## Troubleshooting
- Services won’t start: check Docker resources and port conflicts
- Tests can’t reach DB/ES: ensure use of `bin/dc-run`
- Missing translations: run `bin/dc-run bin/i18n add-missing`

