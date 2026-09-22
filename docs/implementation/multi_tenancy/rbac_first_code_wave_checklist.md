# RBAC First Code Wave Checklist

**Date:** March 12, 2026  
**Status:** Implementation checklist  
**Purpose:** Define the first bounded code wave for RBAC role-identifier migration without yet performing the full policy refactor

**Depends On:** `rbac_identifier_migration_plan.md`, `rbac_role_permission_matrix.md`, `rbac_policy_coverage_matrix.md`

---

## Summary

This checklist defines the first code wave for the RBAC migration.

Its purpose is to make the new canonical role identifiers usable in CE while preserving compatibility with:

- existing live data
- current bootstrap/setup flows
- current factories and test helpers
- the current spec suite during transition

This wave is intentionally narrow.

It should not yet attempt:

- the full policy refactor
- full production data migration
- removal of legacy identifiers
- federation-specific authorization implementation

---

## Scope

### In Scope

- seed/builder support for canonical role identifiers
- temporary compatibility support for legacy identifiers
- setup wizard bootstrap alignment
- factory trait and test-helper compatibility
- canonical auth-tag introduction for the test suite
- basic coverage proving canonical identifiers can coexist with legacy ones

### Out Of Scope

- replacing `manage_platform` across policies
- refactoring invitation and membership policies
- Joatu connection-request authorization
- mirrored-content authorization
- production data migration of memberships and invitations
- retirement of legacy roles

---

## Target Outcome

After this wave:

- `platform_steward`, `analytics_viewer`, and `community_organizer` exist in seeds
- setup/bootstrap can create canonical-role assignments
- tests can authenticate with canonical tags and helpers
- legacy helpers still work by forwarding to canonical identifiers
- no production data remap is required yet

---

## Work Package 1: Seed And Builder Compatibility

### Files

- `app/builders/better_together/access_control_builder.rb`
- related seed tasks/specs

### Tasks

- add canonical platform roles:
  - `platform_steward`
  - `analytics_viewer`
- add canonical community role:
  - `community_organizer`
- assign canonical permission bundles based on `rbac_role_permission_matrix.md`
- keep legacy identifiers seeded temporarily:
  - `platform_manager`
  - `platform_analytics_viewer`
  - `community_coordinator`
  - `community_facilitator`
- ensure legacy identifiers either:
  - receive compatibility bundles, or
  - are clearly marked transitional in builder comments/tests

### Acceptance Criteria

- running the RBAC builder produces both canonical and transitional legacy roles
- canonical roles have the intended permission bundles
- no existing seed spec fails solely because the new canonical roles were added

---

## Work Package 2: Setup Wizard Bootstrap Alignment

### Files

- `app/controllers/better_together/setup_wizard_steps_controller.rb`

### Tasks

- change host-platform bootstrap from `platform_manager` to `platform_steward`
- keep host-community bootstrap on `community_governance_council`
- add a compatibility fallback during transition:
  - prefer `platform_steward`
  - fall back to `platform_manager` only if canonical role is not yet present
- add a short code comment explaining that this is the canonical stewardship role migration point

### Acceptance Criteria

- new bootstrap flow assigns the canonical platform role
- bootstrap still works in environments where legacy seeds are still present
- host-community governance role remains distinct

---

## Work Package 3: Factory Trait Compatibility

### Files

- `spec/factories/better_together/users.rb`
- `spec/factories/better_together/community_invitations.rb`
- `spec/factories/better_together/invitations.rb`

### Tasks

- add canonical traits:
  - `:platform_steward`
  - later if needed: `:analytics_viewer`
- keep legacy `:platform_manager` trait temporarily, but have it assign the canonical `platform_steward` role when present
- add `:with_community_organizer_role` invitation traits
- keep legacy coordinator/facilitator invitation traits temporarily as aliases or compatibility wrappers

### Acceptance Criteria

- factories can create records using canonical identifiers
- legacy traits still work during transition
- the suite can move incrementally instead of all at once

---

## Work Package 4: Test Authentication Helper Compatibility

### Files

- `spec/support/automatic_test_configuration.rb`
- `spec/support/better_together/capybara_feature_helpers.rb`
- `spec/support/better_together/devise_session_helpers.rb`
- `spec/support/seed_helper.rb`

### Tasks

- add canonical metadata tags:
  - `:as_platform_steward`
  - optionally `:platform_steward`
- add canonical helper methods:
  - `capybara_login_as_platform_steward`
  - `login_as_platform_steward`
- keep legacy tags and helper names, but forward them to canonical behavior
- update auto-authentication comments and debug logging to mention stewardship terminology
- ensure test-user creation can request canonical role identifiers

### Acceptance Criteria

- new specs can use `:as_platform_steward`
- old specs using `:as_platform_manager` still pass through compatibility routing
- helper implementation resolves to canonical role assignment when available

---

## Work Package 5: Invitation Test Helper Compatibility

### Files

- `spec/support/helpers/invitation_test_helpers.rb`

### Tasks

- add canonical organizer helpers:
  - `ensure_community_organizer_role_with_permissions`
  - `make_community_organizer`
- keep `ensure_community_coordinator_role_with_permissions` and `make_community_coordinator` temporarily as wrappers
- retire `community_facilitator` creation from active test flows where possible
- document that coordinator/facilitator are transitional compatibility names only

### Acceptance Criteria

- invitation-related specs can move to `community_organizer`
- legacy coordinator/facilitator helpers do not block the transition

---

## Work Package 6: Minimal Seed And Spec Updates

### Files

- `spec/tasks/better_together/seed_rbac_and_navigation_spec.rb`
- targeted model/spec files that directly assert legacy identifiers

### Tasks

- update seed specs to assert canonical roles exist
- keep temporary expectations for legacy transitional roles only where needed
- add focused specs for:
  - canonical role creation
  - compatibility fallback from legacy helper names to canonical roles
  - setup wizard canonical assignment

### Acceptance Criteria

- specs explicitly confirm canonical role presence
- compatibility behavior is covered by targeted tests
- no broad suite rewrite is required in this wave

---

## Suggested Execution Order

1. builder/seeds
2. setup wizard bootstrap
3. user factory canonical trait
4. auth helper tags and aliases
5. invitation helper aliases
6. targeted specs for canonical-role availability and compatibility

This order minimizes breakage because the builder and factories establish the canonical roles before helpers and tests begin depending on them.

---

## Verification Checklist

- canonical roles are present after seed/build
- setup wizard assigns `platform_steward`
- `create(:user, :platform_steward)` works
- `create(:user, :platform_manager)` still works during transition
- `:as_platform_steward` authenticates in request/controller/feature contexts
- `:as_platform_manager` still authenticates through compatibility routing
- invitation helper can create organizer-role memberships

---

## Stop Conditions

Stop this wave and reassess if:

- canonical seed roles cannot coexist cleanly with legacy roles
- setup/bootstrap reveals hidden dependence on legacy role names in production flows
- helper compatibility requires changing policy logic rather than just identifier resolution
- unrelated worktree changes conflict with the RBAC touchpoints in the same files

---

## Next Wave After This Checklist

After this compatibility wave is complete, the next code wave should be the actual policy refactor for `P0` domains:

- `platform_policy`
- `person_platform_membership_policy`
- `person_community_membership_policy`
- invitation policies
- `role_policy`
- `resource_permission_policy`
- `joatu/request_policy`
- `joatu/agreement_policy`
- `message_policy`

