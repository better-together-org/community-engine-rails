# Content Reporting Stakeholder Flows

This document describes the current Community Engine reporting and content-safety workflow for the main stakeholder stories affected by the shared feedback-surface work in the `0.11.0` line.

It is the canonical narrative companion to:

- the shared feedback surface in `shared/_feedback_surface`
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

- the entry point is the shared feedback surface with an explicit scope label such as `Page feedback`, `Community feedback`, or `Section feedback`
- individual content blocks inherit the same surface through the engine-owned block wrapper, so people can flag a specific page section instead of only the whole page
- the live action stays visible on the page instead of hiding behind a second ellipsis menu
- the surface is intentionally designed as a reusable contribution area so future reviewed actions can be added without inventing another page-level affordance
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

- the same feedback-surface contract is reused across the main user-facing reporting surfaces, including individual reportable blocks
- non-JS behavior is first-class because the live report action is rendered directly as a normal link/button, not as a JS-only control
- the shared surface keeps a clear seam for future governed actions without shipping them live yet
- host apps keep their own `extra_block_components` override seam; CE now wraps that host content inside the shared block-action structure instead of replacing it
- screenshot guidance now requires callouts to avoid covering the reviewed component and its nearby evidence, and the surface no longer depends on a hidden menu state to be reviewable

Supporting evidence:

- `docs/development/pull_request_evidence_standard.md`
- `docs/development/screenshot_and_documentation_tooling_assessment.md`
- `docs/development/feedback_surface_policy_matrix.md`
- `skills/ce-visual-review/SKILL.md`

### 5. Future audit and revision-history work

**User story:** As a governance steward, I need auditability today and a clear seam for richer content revision history later.

Current posture:

- this tranche keeps the agreed assessment-only seam for revision history
- Community Engine currently relies on `public_activity` for audit events
- this tranche does **not** introduce a content-versioning gem or user-facing revision browser
- any future revision-history work should preserve the current reporter/reviewer contracts and extend them rather than replacing them

## Accessibility and navigation expectations

- The reporting action should be reachable directly from the visible feedback surface on the content page.
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

- `app/views/shared/_feedback_surface.html.erb`
- `app/helpers/better_together/feedback_surface_helper.rb`
- `app/policies/better_together/feedback_policy.rb`
- `app/controllers/better_together/report_followups_controller.rb`
- `app/controllers/better_together/reports_controller.rb`
- `app/policies/better_together/report_policy.rb`
- `spec/docs_screenshots/better_together/content_reporting_actions_spec.rb`
