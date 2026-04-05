# Better Together Community Privacy Visibility System

## Overview

PR `#1150` extends the shared `BetterTogether::Privacy` concern with a third visibility level: `community`.

The goal of this privacy level is to support content that should not be world-readable, but also should not be restricted to only creators, managers, or explicitly invited/private viewers. In the current implementation, `community` means:

- **guests** only see `public`
- **signed-in people** can see `public` and `community`
- **creators, managers, members, hosts, and invitees** keep their existing additive access paths for `private` and special cases

This PR completes the minimum coherent rollout for that contract across the shared privacy concern, primary policy scopes, UI selectors, and reviewer evidence.

## Behavior Contract

| Audience | `public` | `community` | `private` |
| --- | --- | --- | --- |
| Guest | Yes | No | No |
| Signed-in person | Yes | Yes | No |
| Creator / author | Yes | Yes | Yes, for owned records where policy already grants it |
| Platform / community manager | Yes | Yes | Yes |
| Member / invite / host special cases | Existing policy-specific rules still apply | Existing policy-specific rules still apply | Existing policy-specific rules still apply |

## Core Implementation

### Shared concern

- `app/models/concerns/better_together/privacy.rb`
  - adds `community` to `PRIVACY_LEVELS`
  - adds `privacy_community`
  - preserves translated enum support through `translate_enum :privacy`

### Shared policy helpers

- `app/policies/better_together/application_policy.rb`
  - adds shared `public_or_signed_in_community?` record helper
  - updates the default scope logic so signed-in people can see `privacy IN ('public', 'community')`
  - keeps `private` gated behind existing management, ownership, membership, or invitation paths

### Updated user-facing policy surfaces

This PR extends community visibility on the primary content and community browsing paths:

- `PagePolicy`
- `PostPolicy`
- `ChecklistPolicy`
- `ChecklistItemPolicy`
- `CommunityPolicy`
- `EventPolicy`
- `CallForInterestPolicy`
- `CalendarPolicy`
- `PlatformPolicy`

`PersonPolicy` already had richer community-aware logic and remains the most specialized privacy scope in this area.

## Authoring UI

The privacy level has to be a real authoring option, not just a stored enum value.

This PR ensures the checklist edit form uses the shared `privacy_field` helper so it stays aligned with the current enum list. The checklist item form already used the shared helper; its updated help text now matches the actual available visibility model.

## Reviewer Evidence

### Diagrams

- Source: `docs/diagrams/source/community_privacy_visibility_flow.mmd`
- Source: `docs/diagrams/source/community_privacy_policy_surfaces.mmd`
- Rendered exports:
  - `docs/diagrams/exports/png/community_privacy_visibility_flow.png`
  - `docs/diagrams/exports/svg/community_privacy_visibility_flow.svg`
  - `docs/diagrams/exports/png/community_privacy_policy_surfaces.png`
  - `docs/diagrams/exports/svg/community_privacy_policy_surfaces.svg`

### Screenshots

- `docs/screenshots/desktop/community_privacy_checklist_form.png`
- `docs/screenshots/mobile/community_privacy_checklist_form.png`
- `docs/screenshots/desktop/community_privacy_badge.png`
- `docs/screenshots/mobile/community_privacy_badge.png`

These screenshots are generated from `spec/docs_screenshots/better_together/community_privacy_review_spec.rb`.

## Spec Coverage

This PR adds targeted evidence instead of relying only on a broad concern spec:

- `spec/models/better_together/concerns/privacy_spec.rb`
- `spec/policies/better_together/page_policy_spec.rb`
- `spec/policies/better_together/post_policy_spec.rb`
- `spec/policies/better_together/checklist_policy_spec.rb`
- `spec/policies/better_together/checklist_item_policy_spec.rb`
- `spec/policies/better_together/community_policy_spec.rb`
- `spec/policies/better_together/call_for_interest_policy_spec.rb`
- `spec/policies/better_together/event_policy_spec.rb`
- `spec/policies/better_together/platform_policy_spec.rb`
- `spec/requests/better_together/checklists_spec.rb`

The key assertions now prove that:

- guests cannot see community-scoped records on the covered surfaces
- signed-in users can see community-scoped records
- creator / manager / invitation rules still work as before
- the checklist edit form actually renders the `community` option

## Accessibility And Help Text

- Privacy remains exposed through the shared select control used elsewhere in Better Together.
- The checklist item help text now accurately describes the available visibility choices.
- Screenshot evidence captures both authoring and rendered-display states so reviewers can confirm the help text and badge language visually.

## Risks And Boundaries

- This PR intentionally completes the **primary browsing and authoring surfaces** first. Additional specialized privacy-heavy areas can reuse the same shared helpers and contract if they need follow-up.
- `community` is currently implemented as **signed-in visibility**, not a deeper per-community membership ACL across every model. Where a policy already has stronger member/invite/host logic, that logic stays additive and more specific.

