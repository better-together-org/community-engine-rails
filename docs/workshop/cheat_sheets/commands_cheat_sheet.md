# Commands Cheat Sheet

Use these commands during workshops and daily development.

## Core
- Run tests: `bin/dc-run bin/ci`
- RSpec (file): `bin/dc-run bundle exec rspec spec/path/to/file_spec.rb`
- RSpec (line): `bin/dc-run bundle exec rspec spec/path/to/file_spec.rb:123`
- Lint: `bin/dc-run bundle exec rubocop`
- Security: `bin/dc-run bundle exec brakeman --quiet --no-pager`
- I18n normalize: `bin/dc-run bin/i18n normalize`
- I18n health: `bin/dc-run bin/i18n health`

## Docker & Services
- Up services: `./bin/dc-up`
- Restart: `./bin/dc-restart`
- Logs: `./bin/dc-logs`

## Diagrams
- Render all: `./bin/render_diagrams --force`
- Render specific: `./bin/render_diagrams events_flow.mmd`

## Rails (Dummy App Context)
- Console: `bin/dc-run-dummy rails console`
- Migrate: `bin/dc-run-dummy rails db:migrate`

## Notes
- Always use `bin/dc-run` for commands that need DB/Redis/ES
- RSpec does not support hyphenated line ranges

