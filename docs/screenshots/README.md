# Documentation Screenshots

Community Engine can generate documentation screenshots through opt-in Capybara specs under `spec/docs_screenshots/`.

## Purpose

- Create stable review artifacts for user-facing flows.
- Generate screenshot inputs for end-user and operator documentation.
- Capture desktop and mobile evidence for accessibility and help-text reviews.

## How It Works

- `spec/support/capybara_screenshot_engine.rb` provides the screenshot helper.
- `bin/docs_screenshots` and `rake docs:screenshots` run screenshot-only specs.
- Screenshot specs are skipped unless `RUN_DOCS_SCREENSHOTS=1`.
- Outputs are written to:
  - `docs/screenshots/desktop/`
  - `docs/screenshots/mobile/`

Each screenshot is paired with a JSON sidecar containing metadata such as the source spec, viewport, URL, locale, and capture time.

## Safety Rules

- Do not capture private user data, messages, or moderation details without an explicit review need.
- Prefer seeded test data and deterministic states.
- Treat screenshots as supporting evidence and documentation assets, not as the primary test oracle.
