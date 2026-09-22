# RBAC Coverage Audit 2026-03-12

**Date:** March 12, 2026  
**Status:** First audit pass  
**Assumption:** Assess against the newest schema and current CE worktree state  
**Purpose:** Measure current CE authorization coverage against the federated governance and RBAC planning package

---

## Summary

Current CE has a reusable RBAC foundation, but the authorization layer is still too centered on broad platform authority to safely absorb federated platform connections, OAuth trust, mirrored content, and connection-request workflows.

The main implementation reality is:

- role and permission primitives already exist and should be reused
- many policies still rely on `manage_platform` or `update_platform` as broad bypasses
- platform and community membership authorization is not yet separated cleanly enough for the governance model
- invitation, Joatu, and integration flows are only partially aligned with the future federated network model
- policy coverage is materially incomplete relative to the number of policy files in the codebase

This audit is the bridge between:

- `governance_bodies_and_mandates.md`
- `rbac_role_permission_matrix.md`
- the eventual role migration and policy refactor

---

## Audit Snapshot

### Policy Inventory

- policy files under `app/policies`: 69
- policy spec files under `spec/policies` and `*policy_spec.rb`: 24
- policy files without an obvious matching policy spec: 45

That is not proof that every uncovered policy is untested, but it is a strong signal that policy coverage is materially thinner than the live authorization surface.

### Architectural Baseline

The current RBAC substrate is still viable:

- `BetterTogether::Role`
- `BetterTogether::ResourcePermission`
- `BetterTogether::RoleResourcePermission`
- `BetterTogether::PersonPlatformMembership`
- `BetterTogether::PersonCommunityMembership`
- `BetterTogether::ApplicationPolicy`
- `BetterTogether::Member#permitted_to?`

The main issue is not lack of primitives. The issue is scope shape, policy specificity, and test coverage.

---

## Code-Backed Findings

## 1. Platform Authority Is Still A Broad Bypass

Current policies and scopes still repeatedly treat `manage_platform` as a super-permission.

Evidence:

- `app/policies/better_together/application_policy.rb`
- `app/policies/better_together/page_policy.rb`
- `app/policies/better_together/post_policy.rb`
- `app/policies/better_together/invitation_policy.rb`
- `app/policies/better_together/joatu/request_policy.rb`
- `app/policies/better_together/joatu/offer_policy.rb`
- `app/views/better_together/pages/index.html.erb`
- `app/views/better_together/people/show.html.erb`

Impact:

- platform-wide authority currently leaks into content, visibility, invitations, Joatu exchange visibility, and people pages
- federation-sensitive actions would inherit the same blunt power unless explicitly split out
- the planned distinction between `platform_steward` and `network_admin` does not exist in code today

Required change:

- replace broad `manage_platform` checks with narrower permission families from `rbac_role_permission_matrix.md`

---

## 2. Seeded Platform Roles Are Overlapping And Overpowered

The seeded platform role catalog remains wider than the distinct behaviors currently enforced.

Evidence:

- `app/builders/better_together/access_control_builder.rb`

Observed shape:

- `platform_manager`
- `platform_infrastructure_architect`
- `platform_tech_support`
- `platform_developer`
- `platform_quality_assurance_lead`
- `platform_accessibility_officer`

all receive near-identical platform-management permission sets, including:

- `manage_platform`
- `manage_platform_api`
- `manage_platform_database`
- `manage_platform_deployment`
- `manage_platform_roles`
- `manage_platform_security`
- `manage_platform_settings`

Impact:

- role names imply responsibility specialization
- permission assignments do not actually enforce those distinctions
- this weakens both least-privilege and governance clarity

Required change:

- collapse or retire overlapping platform-specialist roles unless they get genuinely distinct permission bundles
- migrate `platform_manager` toward `platform_steward`
- add a separate `network_admin` permission boundary instead of inheriting it from broad platform management

---

## 3. Platform Membership Governance Is Too Coarse

Platform membership policy still treats `update_platform` as the main gate.

Evidence:

- `app/policies/better_together/person_platform_membership_policy.rb`

Observed shape:

- `index?`, `create?`, `edit?`, `update?`, and `destroy?` all hinge on `update_platform`
- deletion blocks removal of someone who can `manage_platform`, but there is no finer distinction between:
  - platform stewardship
  - support workflow
  - network administration
  - safety intervention

Impact:

- platform membership management does not yet align with the planned role families
- federated roles like `network_admin` cannot be introduced safely without policy refactor

Required change:

- split platform membership permissions into:
  - `manage_platform_members`
  - `manage_platform_roles`
  - safety/support-limited variants where needed

---

## 4. Community Membership Governance Is Underspecified

Community membership policy is narrower than platform membership policy, but still not aligned with the formal distinction between governance and operations.

Evidence:

- `app/policies/better_together/person_community_membership_policy.rb`

Observed shape:

- `create?`, `edit?`, and `destroy?` hinge on `update_community`
- there is no policy distinction between:
  - `community_governance_council`
  - `community_organizer`
  - community safety or asset stewardship roles

Impact:

- the host community governance model is not represented cleanly in authorization
- organizers and governance bodies cannot be separated by permission today

Required change:

- split community permissions into:
  - `manage_community_members`
  - `manage_community_roles`
  - `manage_community_content`
  - `invite_members`

---

## 5. Invitation Authorization Is Still Platform-Centric

Invitation policies do include invitable-specific checks, but they still fall back to broad platform authority.

Evidence:

- `app/policies/better_together/invitation_policy.rb`
- `app/policies/better_together/platform_invitation_policy.rb`
- `app/policies/better_together/community_invitation_policy.rb`
- `app/controllers/concerns/better_together/invitation_token_authorization.rb`

Observed shape:

- `InvitationPolicy#create?` allows broad `manage_platform` fallback
- `InvitationPolicy::Scope` returns `scope.all` for actors with `manage_platform`

Impact:

- platform-level authority can flatten invitation visibility and invitation creation
- this conflicts with the governance model where platform stewardship and community governance remain distinct

Required change:

- make platform and community invitation policy hinge on scoped membership-management permissions
- keep invitation-token access paths, but do not use platform-superuser fallback as the default policy model

---

## 6. Joatu Is Not Yet Ready For Connection Requests

The existing Joatu request/offer/agreement model is usable, but its authorization is not yet scoped for platform/community/person connection workflows.

Evidence:

- `app/policies/better_together/joatu/request_policy.rb`
- `app/policies/better_together/joatu/offer_policy.rb`
- `app/policies/better_together/joatu/agreement_policy.rb`
- `app/models/better_together/joatu/request.rb`
- `app/models/better_together/joatu/offer.rb`
- `app/models/better_together/joatu/agreement.rb`

Observed shape:

- any signed-in user can create requests and offers
- platform-wide `manage_platform` grants full scope visibility
- request update/destroy authority is creator-or-platform-manager based

Impact:

- this is too loose for `ConnectionRequest` as the shared primitive for:
  - person-to-person
  - person-to-community
  - community-to-community
  - platform-to-platform

Required change:

- introduce source/target-type-aware policy branches
- reserve platform-to-platform connection authority for `network_admin`
- tie community-to-community authority to community governance

---

## 7. Integrations Are User-Owned, But Not Yet Federation-Aware

`PersonPlatformIntegrationPolicy` is currently a good fit for ordinary user-owned external integrations, but not yet for CE federation.

Evidence:

- `app/policies/better_together/person_platform_integration_policy.rb`
- `app/models/better_together/person_platform_integration.rb`

Observed shape:

- CRUD is user-owned by `record.user_id == user.id`
- there is no platform-trust, sharing, or mirrored-content layer here

Impact:

- the current policy is fine for personal social integrations
- it is not enough for CE-to-CE OAuth trust, linked-platform accounts, or publish-back authorization

Required change:

- either introduce separate federation models and policies
- or heavily specialize the integration model so personal integrations and CE federation are not conflated

---

## 8. Message And Conversation Coverage Is Uneven

Messaging exists, but policy maturity is not where it needs to be for federated or mirrored workflows.

Evidence:

- `app/policies/better_together/message_policy.rb`
- `app/policies/better_together/conversation_policy.rb`

Observed shape:

- `MessagePolicy` is effectively a placeholder with an empty scope
- conversation authorization has more substance, but the messaging surface is not yet represented by a complete action matrix

Impact:

- message and conversation rules will need clarification before any cross-platform sharing or connection-request messaging layer is built on top

Required change:

- write explicit message/conversation action matrices
- decide whether messaging remains purely local or participates in the federated network model

---

## 9. Core Permission Resolution Is Membership-Centric And Reusable

The underlying permission resolution model still fits the planned architecture.

Evidence:

- `app/models/concerns/better_together/member.rb`

Observed shape:

- permissions resolve through role-resource-permission associations
- record-specific permission checks depend on membership against the joinable resource

Impact:

- this supports the platform/community scope model well
- the RBAC redesign can build on current primitives rather than replacing them

Constraint:

- cache-heavy permission lookup will need careful invalidation around role renames, migration, and cross-platform additions

---

## 10. Test Coverage And Helpers Still Encode The Old Platform-Manager World

The test suite and support helpers still assume `platform_manager` as the dominant elevated actor.

Evidence:

- `spec/support/automatic_test_configuration.rb`
- `spec/support/better_together/devise_session_helpers.rb`
- `spec/support/better_together/capybara_feature_helpers.rb`
- `spec/support/seed_helper.rb`
- `app/controllers/better_together/setup_wizard_steps_controller.rb`

Observed shape:

- `:as_platform_manager` is a common test shortcut
- helper users default to `platform_manager`
- setup flows still assign `platform_manager`

Impact:

- role identifier migration will ripple through request specs, feature specs, helpers, and setup flows
- authorization cleanup cannot be considered finished until test helpers reflect the new role vocabulary

Required change:

- replace test helpers with canonical-role helpers such as:
  - `:as_platform_steward`
  - `:as_network_admin`
  - `:as_community_governance_council`
  - `:as_community_organizer`

---

## Coverage Gap Signals

## Policies Missing Obvious Direct Spec Coverage

First-pass comparison found 45 policy files without an obvious matching policy spec, including:

- `app/policies/better_together/address_policy.rb`
- `app/policies/better_together/calendar_policy.rb`
- `app/policies/better_together/contact_detail_policy.rb`
- `app/policies/better_together/event_policy.rb`
- `app/policies/better_together/message_policy.rb`
- `app/policies/better_together/navigation_area_policy.rb`
- `app/policies/better_together/navigation_item_policy.rb`
- `app/policies/better_together/person_community_membership_policy.rb`
- `app/policies/better_together/person_platform_integration_policy.rb`
- `app/policies/better_together/platform_invitation_policy.rb`
- `app/policies/better_together/platform_policy.rb`
- `app/policies/better_together/post_policy.rb`
- `app/policies/better_together/resource_permission_policy.rb`
- `app/policies/better_together/role_policy.rb`
- `app/policies/better_together/user_policy.rb`

This list is not exhaustive here, but the overall count is enough to justify a focused coverage workstream.

## Placeholder Or Minimal Policies

High-risk examples include:

- `app/policies/better_together/message_policy.rb`
- `app/policies/better_together/person_community_membership_policy.rb`
- `app/policies/better_together/person_platform_membership_policy.rb`

Some scopes also simply return `scope.all` where the federated model will need tighter visibility controls.

---

## Priority Refactor Order

## Priority 1: Governance-Critical

- platform membership policy
- community membership policy
- invitation policies
- role and resource-permission policies
- platform policy

## Priority 2: Federation-Critical

- platform connection policy layer
- OAuth trust and linked-account policy layer
- Joatu request/offer/agreement policies for connection requests
- mirrored-content policy layer

## Priority 3: Visibility And Moderation

- post, page, event, navigation, and content block policies
- conversation and message policies
- people/profile visibility policies

## Priority 4: Supporting Domains

- metrics/reporting
- geography/maps
- uploads and contact details

---

## Recommended Next Artifacts

1. `rbac_policy_coverage_matrix.md`
- map key models/controllers to:
  - current policy
  - current spec coverage
  - target permission family
  - migration priority

2. `rbac_identifier_migration_plan.md`
- map current identifiers, invitations, memberships, seeds, and helper tags to target identifiers

3. model-specific action matrices for:
- platform memberships
- community memberships
- invitations
- Joatu connection requests
- mirrored content
- messaging

---

## Conclusion

CE is not blocked by missing authorization primitives. It is blocked by an authorization layer that still assumes one broad platform-management role can safely anchor most elevated actions.

That assumption no longer holds for the federated model.

The next implementation step should be a policy coverage matrix and migration plan that refactors high-risk domains first:

- membership
- invitations
- platform/network governance
- Joatu connection requests
- mirrored content

