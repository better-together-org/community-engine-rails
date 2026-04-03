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

## Release packet naming

When screenshots are captured specifically for a release note or release review packet, use a stable release-prefixed slug so the assets are easy to inventory and validate:

- desktop: `docs/screenshots/desktop/release_0_11_0_<slug>.png`
- mobile: `docs/screenshots/mobile/release_0_11_0_<slug>.png`

Examples:

- `release_0_11_0_member_data_export`
- `release_0_11_0_person_deletion_request`
- `release_0_11_0_uploads_gallery`
- `release_0_11_0_block_image_library`

Prefer matching JSON sidecars for each screenshot so release-note inventories can confirm source spec, route, viewport, and capture metadata without opening the image.

## Safety Rules

- Do not capture private user data, messages, or moderation details without an explicit review need.
- Prefer seeded test data and deterministic states.
- Treat screenshots as supporting evidence and documentation assets, not as the primary test oracle.
- For release packets, only reference screenshots that exist on the release branch tip.
