# Module 02 — Local Setup (Docker)

> Duration: 40–60 minutes

---

## Objectives

- Start full stack using project scripts
- Run tests, linting, security, i18n tools
- Understand `bin/dc-run` vs `bin/dc-run-dummy`

---

## Commands

- `./bin/dc-up`
- `bin/dc-run bin/ci`
- `bin/dc-run bundle exec rubocop`
- `bin/dc-run bundle exec brakeman --quiet --no-pager`
- `bin/dc-run bin/i18n all`

---

## Troubleshooting

- Docker resources and port conflicts
- Use `bin/dc-run` for DB/Redis/ES tasks
- Add missing translations then re-run health

