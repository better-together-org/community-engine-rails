# Screenshot And Documentation Tooling Assessment

This assessment records the current-state tooling used for browser accessibility checks, screenshot generation, and documentation generation across Community Engine and management-tool.

## Community Engine

| Tooling | Location | Assessment |
|---|---|---|
| Capybara Selenium feature setup | `spec/support/capybara.rb` | Adopt as-is |
| axe-core integration | `spec/support/axe.rb` | Adopt as-is |
| Accessibility feature-spec pattern | `spec/features/better_together/timezone_selector_accessibility_spec.rb` | Adopt as-is |
| Screenshot-engine branch concepts | `enhancement/screenshot-engine` | Adopt with cleanup |
| Diagram tooling validation | `docs/scripts/validate_documentation_tooling.sh` | Adopt with cleanup |
| Swagger generation | `bin/swagger_generate`, `lib/tasks/swagger.rake` | Adopt as-is |

### Notes

- Community Engine already has the right browser-testing foundation.
- The screenshot-engine branch contains useful, isolated ideas:
  - docs screenshot specs
  - desktop/mobile capture
  - metadata sidecars
- It should not be merged wholesale because the branch diverges heavily from current `main`.
- Current `main` now carries the key placement hardening needed for review-safe annotations:
  - callouts can keep a precise highlight target while separately avoiding a broader parent container
  - screenshot specs can pass `avoid_container_selector` when the highlighted element is a badge or label inside a larger review surface
  - the generated metadata sidecar records both `target` and `avoid` rectangles, which makes placement regressions diagnosable without re-running the browser manually

## management-tool

| Tooling | Location | Assessment |
|---|---|---|
| Selenium screenshot skill | `skills/selenium-screenshot/SKILL.md` | Adopt with cleanup |
| Screenshot capture service | `tools/selenium-screenshot/app.py` | Adopt with cleanup |
| Selenium stack compose file | `compose.selenium.yml` | Adopt with cleanup |
| UI automation preflight | `scripts/ui_automation_doctor.py` | Adopt as-is |
| CLI documentation generation | `scripts/generate_cli_tooling_docs.py` | Adopt as-is for tooling inventory, not end-user docs |

### Notes

- management-tool owns the stronger operational screenshot service.
- Community Engine owns the user-facing page-state and Capybara-driven docs screenshots.
- The best long-term shape is integration, not duplication.

## Recommended Division Of Responsibility

- Community Engine
  - browser semantics
  - accessibility assertions
  - docs screenshot intent and naming
  - canonical rubric and user-facing documentation standards
- management-tool
  - Selenium service operations
  - screenshot environment preflight
  - reusable capture infrastructure
  - tooling inventory generation

## Current Gaps

- Community Engine documentation has stale references to accessibility guidance paths.
- Screenshot generation was previously explored but not carried through into current `main`.
- No single rubric previously governed both docs and inline help text.

## Review-safe callout contract

- Prefer surrounding whitespace for annotation placement rather than overlaying the reviewed surface.
- If the selector being highlighted is nested inside a larger card/panel, configure the screenshot spec to avoid the larger container, not just the inner selector.
- Treat the JSON metadata next to each screenshot as part of the review artifact. It should show a sensible `placement` plus an `avoid` rectangle that matches the real UI component.
