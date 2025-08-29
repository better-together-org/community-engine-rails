# Contributing

Thank you for contributing to Better Together Community Engine!

## Expectations for Changes

- Tests: Keep tests green (`bin/ci`). Add/adjust specs for new behavior.
- Lint & Security: Run `bundle exec rubocop`, `bundle exec brakeman -q -w2`, and `bundle exec bundler-audit --update`.
- Documentation & Diagrams:
  - Update or add docs under `docs/` for any new functionality, routes, background jobs, or changes to models/associations.
  - Maintain Mermaid diagrams (`docs/*.mmd`) that reflect updated relationships and process flows.
  - Render PNGs from `.mmd` using `bin/render_diagrams` and commit the outputs.
  - PRs that change models, associations, or flows must include docs/diagram updates.
- Accessibility, i18n, and policies: Follow AGENTS.md and `.github/instructions/*` guides.

## Development

- Use the setup in README/AGENTS.md (Docker or local).
- Test app lives in `spec/dummy`.
- For exchange (Joatu) features, see `docs/joatu/*` and `docs/exchange_process.md`.

## Pull Requests

- Keep PRs focused and small where possible.
- Include a brief description of why, how, and impact.
- If adding migrations: note any data backfills or dedupe steps.
- If modifying notifications: describe dedupe/throttling strategy.

## Questions

Open a discussion or issue if you’re unsure about direction or scope.
