# Feature Access Grants And Developer Settings

## Overview

This branch tightens two related platform-management surfaces:

- host-admin managed feature access grants are now authorized against the target platform rather than broad host-global access alone
- the `developer_settings` gate now blocks direct access to personal OAuth application routes instead of only hiding the Settings tab

It also hardens feature lifecycle behavior so retired feature keys do not break the grant admin UI or historical records.

## The `FeatureAccessGrant` model

`BetterTogether::FeatureAccessGrant` (`better_together_feature_access_grants`, a `PlatformRecord`) lets a platform give one person early access to a feature that is still in a limited rollout.

| Attribute | Notes |
|---|---|
| `person` | The person who gets access |
| `granted_by_person` | Optional: who granted it |
| `feature_key` | Required; must be a key in `FeatureRegistry` (an unchanged key on an existing record is allowed even if the feature was later retired, so history stays valid) |
| `access_level` | `beta` or `alpha` |
| `expires_at`, `revoked_at` | Optional expiry; `revoke!` sets `revoked_at` |

Rules: there can be only one active grant per platform, person and feature. A grant past its `expires_at` is treated as revoked: it revokes itself on validation, and saving a new grant for the same person and feature revokes older expired ones first so they cannot block it. `FeatureAccessGrant.active` returns unrevoked, unexpired grants and `active_now?` is the instance check. Gating itself is decided by `FeatureGate` against `config/feature_gates.yml`; grants only widen access for the named person.

## Visual Flow

```mermaid
flowchart TD
  A[Platform manager opens host feature access grants route] --> B{Authorized for target platform?}
  B -->|No| C[Render 404 host-admin denial]
  B -->|Yes| D[Load target platform grants]
  D --> E{Feature key still registered?}
  E -->|Yes| F[Show current feature label and rollout]
  E -->|No| G[Show Unknown feature fallback label]
  F --> H[Create, edit, or revoke grant]
  G --> H

  I[Signed-in person opens /settings/applications] --> J{developer_settings enabled for Current.platform?}
  J -->|No| K[Render 404 for direct route access]
  J -->|Yes| L[Load personal OAuth applications UI]
```

**Diagram Files:**
- [Mermaid Source](../../diagrams/source/feature_access_grants_and_developer_settings_flow.mmd)
- [PNG Export](../../diagrams/exports/png/feature_access_grants_and_developer_settings_flow.png)
- [SVG Export](../../diagrams/exports/svg/feature_access_grants_and_developer_settings_flow.svg)

## Authorization Boundaries

- Feature grant CRUD now requires `manage_platform` or `manage_platform_settings` on the specific target platform record.
- A host-platform manager without scoped access to another platform is denied with the same `404` contract used by other host admin surfaces.
- Direct personal OAuth application access now follows the `developer_settings` feature gate instead of bypassing it through the route layer.

## Retired Feature Key Handling

- Historical or persisted grants with removed feature keys remain editable for non-key fields.
- The grant index renders `Unknown feature (<key>)` instead of raising.
- The grant form keeps the retired key selectable for persisted records and shows `Unknown / retired feature` for rollout state when the registry no longer knows that key.

## UI Evidence

### Feature access grants index

![Feature access grants index](../../screenshots/desktop/feature_access_grants_index.png)

### Retired feature grant edit form

![Retired feature access grant edit form](../../screenshots/desktop/feature_access_grant_retired_feature_edit.png)

### Direct personal OAuth route blocked when developer settings are off

![Developer settings route blocked](../../screenshots/desktop/developer_settings_personal_oauth_blocked.png)

Mobile captures are generated alongside the desktop variants in `docs/screenshots/mobile/`.

## Verification

- request specs cover scoped platform authorization, direct developer-settings route blocking, and retired feature-key rendering
- model and policy specs cover retired key persistence and gated OAuth policy behavior
- the docs screenshot spec exercises the grant index, retired-feature edit form, and blocked personal OAuth route with live rendered captures
