# Content Reporting Stakeholder Flows

This document describes the current Community Engine reporting and content-safety workflow for the main stakeholder stories affected by the shared content-actions work in the `0.11.0` line.

It is the canonical narrative companion to:

- the shared actions UI in `shared/_content_actions`
- the reporter follow-up / appeal path on `ReportsController#show`
- the held-content reviewer queue and content-security release states
- the screenshot and diagram evidence generated for PR review

## Canonical diagram

- Source: `docs/diagrams/source/content_reporting_stakeholder_flow.mmd`
- Rendered exports:
  - `docs/diagrams/exports/png/content_reporting_stakeholder_flow.png`
  - `docs/diagrams/exports/svg/content_reporting_stakeholder_flow.svg`

## Stakeholder stories

### 1. Community member or participant reporting a content concern

**User story:** As a person reading content, I need a predictable way to flag a post, page, page section, community, event, message, person, or upload without hunting for a page-specific button.

Current implementation:

- the entry point is the shared ellipsis-style content-actions trigger
- individual content blocks inherit the same actions seam through the engine-owned block wrapper, so people can flag a specific page section instead of only the whole page
- the menu is built with `<details><summary>` so it still works without JavaScript
- the Stimulus controller only enhances keyboard state, outside-click close behavior, and future extension hooks
- the report form now keeps the originating record visible so the person can confirm they are reporting the intended surface

Primary screenshots:

- `docs/screenshots/desktop/content_reporting_actions_post_menu.png`
- `docs/screenshots/desktop/content_reporting_actions_block_menu.png`
- `docs/screenshots/desktop/content_reporting_actions_community_menu.png`
- `docs/screenshots/desktop/content_reporting_actions_report_form.png`
- review packet copies under `docs/screenshots/review/pr-1504/`

### 2. Reporter adding evidence or appealing a decision

**User story:** As the reporting person, I need a supported, authenticated way to add context, contest a decision, or respond to reviewer questions without losing the original report history.

Current implementation:

- each report detail page can show participant-visible safety notes
- the reporting person can add a follow-up note directly on the report page
- this follow-up path is intentionally separate from reviewer-only case-management actions
- the UI copy frames the surface as additional evidence or an appeal note, which gives a clear place for authenticatable follow-up

Primary screenshots:

- `docs/screenshots/desktop/content_reporting_actions_followup.png`
- `docs/screenshots/mobile/content_reporting_actions_followup.png`
- review packet copies under `docs/screenshots/review/pr-1504/`

### 3. Reviewer triaging held or restricted content

**User story:** As a reviewer, I need one queue where I can see held content, understand why it is restricted, and move through pending, approved, rejected, and blocked states without guessing where the item originated.

Current implementation:

- the safety review queue already shows held content items alongside safety cases
- reviewer evidence covers placeholder attachments and upload states under review and under restriction
- the queue and state screenshots document what reviewers see before and after moderation decisions

Primary screenshots:

- `docs/screenshots/desktop/content_security_review_queue.png`
- `docs/screenshots/desktop/content_security_upload_under_review.png`
- `docs/screenshots/desktop/content_security_upload_restricted.png`
- `docs/screenshots/desktop/content_security_placeholder_under_review.png`
- `docs/screenshots/desktop/content_security_placeholder_restricted.png`
- review packet copies under `docs/screenshots/review/pr-1504/`

### 4. Governance, accessibility, and product reviewers

**User story:** As a governance or product reviewer, I need evidence that the flow is accessible, consistent across surfaces, and extensible for future civic-quality actions like correction requests, translation suggestions, or citation improvements.

Current implementation:

- the same content-actions seam is reused across the main user-facing reporting surfaces, including individual reportable blocks
- non-JS behavior is first-class because the menu is based on native disclosure semantics
- the shared menu keeps an explicit extension container for future actions
- host apps keep their own `extra_block_components` override seam; CE now wraps that host content inside the shared block-action structure instead of replacing it
- screenshot guidance now requires callouts to avoid covering the reviewed component and any related revealed UI, such as the opened reporting menu, when whitespace exists nearby

Supporting evidence:

- `docs/development/pull_request_evidence_standard.md`
- `docs/development/screenshot_and_documentation_tooling_assessment.md`
- `skills/ce-visual-review/SKILL.md`

### 5. Future audit and revision-history work

**User story:** As a governance steward, I need auditability today and a clear seam for richer content revision history later.

Current posture:

- this tranche keeps the agreed assessment-only seam for revision history
- Community Engine currently relies on `public_activity` for audit events
- this tranche does **not** introduce a content-versioning gem or user-facing revision browser
- any future revision-history work should preserve the current reporter/reviewer contracts and extend them rather than replacing them

## Accessibility and navigation expectations

- The reporting trigger should be reachable directly from the content surface.
- The report form should preserve enough context that a person can confirm what they are flagging.
- The report detail page should remain the canonical place for participant-visible follow-up and appeal evidence.
- Reviewer evidence should keep held-state and decision-state UI visible in screenshots instead of hiding it beneath annotations.

## Screenshot inventory map

| Story | Canonical screenshots |
| --- | --- |
| Report from post/community/page/block surface | `content_reporting_actions_post_menu`, `content_reporting_actions_block_menu`, `content_reporting_actions_community_menu`, `content_reporting_actions_report_form` |
| Add evidence or appeal | `content_reporting_actions_followup` |
| Reviewer queue and held-content states | `content_security_review_queue`, `content_security_upload_under_review`, `content_security_upload_restricted`, `content_security_placeholder_under_review`, `content_security_placeholder_restricted` |
| Legacy general safety flow references | `report_form`, `report_detail`, `report_history` |

## Related implementation files

- `app/views/shared/_content_actions.html.erb`
- `app/javascript/controllers/better_together/content_actions_controller.js`
- `app/controllers/better_together/report_followups_controller.rb`
- `app/controllers/better_together/reports_controller.rb`
- `app/policies/better_together/report_policy.rb`
- `spec/docs_screenshots/better_together/content_reporting_actions_spec.rb`
