# RBAC Policy Coverage Matrix

**Date:** March 12, 2026  
**Status:** Planning prerequisite  
**Purpose:** Map current CE authorization surfaces to target permission families and migration priority

**Depends On:** `rbac_role_permission_matrix.md`, `federated_rbac_reassessment_and_coverage_plan.md`

---

## Summary

This matrix turns the RBAC coverage audit into an implementation queue.

For each high-priority domain it records:

- the current policy surface
- the current authorization pattern
- whether there is an obvious direct policy spec signal
- the target permission family
- the migration priority for federated CE work

This is not a complete inventory of every policy file in CE. It is the first implementation-focused matrix for the domains that matter most to:

- platform/community governance
- invitations and memberships
- Joatu connection requests
- OAuth and integration flows
- mirrored content and network sharing

---

## Priority Legend

- `P0`
  - must be refactored before federation, mirrored content, or role migration can safely start
- `P1`
  - should be refactored during the same RBAC migration wave as the governance-critical work
- `P2`
  - supporting domain; can follow after the core governance and federation surfaces are corrected

## Spec Signal Legend

- `yes`
  - there is an obvious direct policy spec file
- `partial`
  - coverage may exist indirectly, but there is no clear direct policy spec or the coverage appears draft/thin
- `no`
  - no obvious direct policy spec signal found in the first audit pass

---

## Governance And Membership Domains

| Domain | Current policy / controller | Current authorization shape | Spec signal | Target permission family | Priority | Notes |
|--------|-----------------------------|-----------------------------|-------------|--------------------------|----------|-------|
| platform records | `app/policies/better_together/platform_policy.rb` | `manage_platform` for create/update; broad authenticated visibility for show/index | no | `view_platform`, `edit_platform`, `manage_platform_settings` | P0 | must separate platform stewardship from federation/network authority |
| platform memberships | `app/policies/better_together/person_platform_membership_policy.rb` / `app/controllers/better_together/person_platform_memberships_controller.rb` | `update_platform` gates most actions; destroy blocks removing someone with `manage_platform` | yes | `manage_platform_members`, `manage_platform_roles` | P0 | central governance refactor point |
| community memberships | `app/policies/better_together/person_community_membership_policy.rb` | `update_community` gates create/edit/destroy | no | `manage_community_members`, `manage_community_roles` | P0 | needs explicit split between governance council and organizers |
| role registry | `app/policies/better_together/role_policy.rb` | current role-management surface not yet aligned to new canonical catalog | no | `manage_platform_roles`, `manage_community_roles` | P0 | role migration depends on this |
| resource permissions | `app/policies/better_together/resource_permission_policy.rb` | mostly read-only, no explicit steward-level governance boundary | no | `manage_platform_roles`, `manage_community_roles` | P0 | needed for seed cleanup and permission-family migration |
| setup wizard bootstrap | `app/controllers/better_together/setup_wizard_steps_controller.rb` | hard-codes `platform_manager` and `community_governance_council` assignment | n/a | bootstrap to `platform_steward` and host-community governance role | P0 | onboarding/bootstrap must reflect canonical role identifiers |

---

## Invitation Domains

| Domain | Current policy / controller | Current authorization shape | Spec signal | Target permission family | Priority | Notes |
|--------|-----------------------------|-----------------------------|-------------|--------------------------|----------|-------|
| base invitation policy | `app/policies/better_together/invitation_policy.rb` | invitable-specific checks with broad `manage_platform` fallback and full-scope fallback in scope | yes | platform: `manage_platform_members`; community: `invite_members`, `manage_community_members` | P0 | current fallback is too platform-centric |
| platform invitations | `app/policies/better_together/platform_invitation_policy.rb` / `app/controllers/better_together/platform_invitations_controller.rb` | scoped through base invitation policy; role lists still platform/community mixed in UI | no | `manage_platform_members`, `manage_platform_roles` | P0 | needs stewardship-specific invitation model |
| community invitations | `app/policies/better_together/community_invitation_policy.rb` | invitable-specific, but still part of the broad invitation model | yes | `invite_members`, `manage_community_members` | P0 | should preserve distinction between community governance and community operations delegation |
| event invitations | `app/policies/better_together/event_invitation_policy.rb` | invitation-specific, less central to governance migration | yes | `manage_community_content`, event-host delegation | P2 | relevant later for community operations cleanup |

---

## Federation, OAuth, And Connection Domains

| Domain | Current policy / controller | Current authorization shape | Spec signal | Target permission family | Priority | Notes |
|--------|-----------------------------|-----------------------------|-------------|--------------------------|----------|-------|
| person platform integrations | `app/policies/better_together/person_platform_integration_policy.rb` / `app/controllers/better_together/person_platform_integrations_controller.rb` | user-owned CRUD by `record.user_id == user.id` | no | user-owned external integrations; future federation models also need `manage_federation_auth` | P0 | current policy is fine for personal integrations, not for CE federation |
| OAuth user accounts | `app/policies/better_together/oauth_user_policy.rb` | inherits user-policy shape | no | local account governance plus CE federation-specific auth policy | P1 | depends on final CE-to-CE OAuth model |
| Joatu requests | `app/policies/better_together/joatu/request_policy.rb` | signed-in create; creator-or-`manage_platform` update/destroy; broad scope visibility for platform managers | yes | person/community/platform-specific action branches; platform connections require `manage_network_connections` / `approve_network_connections` | P0 | direct blocker for `ConnectionRequest` |
| Joatu offers | `app/policies/better_together/joatu/offer_policy.rb` | same broad platform-manager visibility pattern | yes | aligned with request/agreement refactor | P1 | secondary to request policy |
| Joatu agreements | `app/policies/better_together/joatu/agreement_policy.rb` | broad platform-manager visibility | yes | agreement-backed consent for sharing/auth using explicit federation permissions | P0 | needed for mirroring and OAuth trust consent |
| future platform connections | no dedicated model/policy yet | currently absent | no | `view_network`, `manage_network_connections`, `approve_network_connections` | P0 | must be introduced explicitly, not inferred from `manage_platform` |
| future OAuth trust config | no dedicated policy yet | currently absent | no | `manage_federation_auth` | P0 | must be separate from general platform editing |

---

## Content And Mirrored-Content Candidate Domains

| Domain | Current policy / controller | Current authorization shape | Spec signal | Target permission family | Priority | Notes |
|--------|-----------------------------|-----------------------------|-------------|--------------------------|----------|-------|
| pages | `app/policies/better_together/page_policy.rb` | `manage_platform` or author-based updates; managers see all | yes | `manage_community_content`, `edit_content`, mirrored-content-specific rules later | P1 | needs provenance-aware rules for mirrored pages if adopted |
| posts | `app/policies/better_together/post_policy.rb` | `manage_platform` dominates create/update/destroy; public-or-creator read path | no | `create_content`, `edit_content`, `moderate_content`, mirrored-content rules | P1 | likely early mirrored-content candidate |
| events | `app/policies/better_together/event_policy.rb` | `manage_platform` or event-host membership | no | `manage_community_content`, event-host delegation, mirrored-event rules | P1 | includes invitation token access and host-member logic |
| navigation items | `app/policies/better_together/navigation_item_policy.rb` | any signed-in user can create/update; guests see filtered view | no | `manage_navigation` | P1 | currently too permissive for a stewarded platform/community model |
| content blocks/templates | `app/policies/better_together/content/*_policy.rb` | mostly inherited through block policies | partial | `manage_templates`, `manage_community_content` | P2 | refactor after primary content models |
| people/profile visibility | `app/policies/better_together/person_policy.rb` | person-specific permissions plus `manage_platform` full visibility in scope | no | `read_person`, `update_person`, plus community/network visibility rules | P1 | important for social graph and network boundaries |

---

## Messaging, Safety, And Visibility Domains

| Domain | Current policy / controller | Current authorization shape | Spec signal | Target permission family | Priority | Notes |
|--------|-----------------------------|-----------------------------|-------------|--------------------------|----------|-------|
| conversations | `app/policies/better_together/conversation_policy.rb` | participants-only show; creator update; managers can message anyone via participant helper | yes | local messaging permissions plus later network boundary rules | P1 | still depends on `platform_manager` identifier in participant helper |
| messages | `app/policies/better_together/message_policy.rb` / `app/controllers/better_together/messages_controller.rb` | effectively placeholder | no | explicit message action matrix | P0 | cannot support federated messaging assumptions in current form |
| person blocks | `app/policies/better_together/person_block_policy.rb` | blocks targeting people with `manage_platform` are restricted | yes | `manage_person_blocks`, safety stewardship | P1 | should move away from broad platform-manager special casing |
| reports / safety cases | `app/policies/better_together/report_policy.rb` and related | partial policy surface | yes | `view_safety_cases`, `manage_safety_cases`, `review_reports` | P1 | needs mapping to platform/community safety steward roles |

---

## Metrics And Supporting Domains

| Domain | Current policy / controller | Current authorization shape | Spec signal | Target permission family | Priority | Notes |
|--------|-----------------------------|-----------------------------|-------------|--------------------------|----------|-------|
| metrics reports | `app/policies/better_together/metrics/*_policy.rb` | existing metric-specific policy layer | yes | `view_metrics`, `create_reports`, `download_reports` | P2 | candidate for `analytics_viewer` rename path |
| uploads | `app/policies/better_together/upload_policy.rb` | existing standalone policy | no | content/admin permissions based on parent context | P2 | not a first federation blocker |
| contact details | `app/policies/better_together/contact_detail_policy.rb` and subclasses | existing scoped policy family | no | person/profile and community visibility permissions | P2 | revisit once person visibility model is settled |
| geography/maps | `app/policies/better_together/geography/*_policy.rb` | mixed scope behavior, not governance critical | no | supporting content permissions | P2 | lower priority for federated rollout |

---

## Immediate Refactor Queue

### Wave 1: Governance-Critical

1. `platform_policy`
2. `person_platform_membership_policy`
3. `person_community_membership_policy`
4. `invitation_policy` plus platform/community invitation subclasses
5. `role_policy`
6. `resource_permission_policy`
7. setup/bootstrap role assignment

### Wave 2: Federation-Critical

1. `joatu/request_policy`
2. `joatu/agreement_policy`
3. federation-specific models and policies for platform connections and OAuth trust
4. `person_platform_integration_policy` split or specialization
5. mirrored-content policy layer

### Wave 3: Content And Messaging

1. `post_policy`
2. `page_policy`
3. `event_policy`
4. `navigation_item_policy`
5. `person_policy`
6. `conversation_policy`
7. `message_policy`

---

## Acceptance Criteria For The Next Implementation Phase

- each `P0` domain is mapped to explicit target permission families
- platform stewardship and network administration are separated in policy
- host-community governance and community operations are separated in policy
- invitation and membership flows no longer rely on broad platform-manager fallback
- Joatu request/agreement flows can support typed connection-request authority
- the codebase has a clear policy refactor order before role-identifier migration begins

