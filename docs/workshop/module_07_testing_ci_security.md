# Module 07 — Testing, CI, Security

Request‑first testing, CI habits, and security hygiene to keep changes safe and verifiable.

## Objectives
- Prefer request specs for controller behavior in an engine
- Use automatic test configuration helpers and metadata tags
- Run CI-equivalent locally with project scripts
- Enforce linting and application security checks pre‑merge

## Testing Patterns
- Request specs exercise full engine routing and privacy hooks; avoid controller specs unless necessary.
- Use automatic configuration helpers (see `spec/support/automatic_test_configuration.rb`) and metadata tags:
  - `:as_platform_manager`, `:as_user`, `:no_auth`, `:skip_host_setup`
- When a controller spec is unavoidable, avoid URL helpers in assertions (use string includes) and configure URL helpers explicitly.

## Commands
- Full suite: `bin/dc-run bin/ci`
- Focused spec: `bin/dc-run bundle exec rspec spec/path/to/file_spec.rb`
- Line focus: `bin/dc-run bundle exec rspec spec/path/to/file_spec.rb:123`
- Verbose descriptions: `--format documentation` (do not use `-v` which shows rspec version)

## CI & Quality Gates
- Lint: `bin/dc-run bundle exec rubocop`
- Security (code): `bin/dc-run bundle exec brakeman --quiet --no-pager`
- Security (deps): `bin/dc-run bundle exec bundler-audit --update`
- i18n: `bin/dc-run bin/i18n all`

## Reading List
- `AGENTS.md` → Testing Requirements, Commands, Security Requirements
- `spec/support/automatic_test_configuration.rb` → automatic host setup and auth
- Testing architecture notes in `AGENTS.md` (Request vs Controller Specs)

## Hands‑On Lab
- Lab 06 — Controller → Request Spec Conversion — `./labs/lab_06_controller_to_request_spec.md`

