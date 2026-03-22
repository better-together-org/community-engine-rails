# RBAC Identifier Migration Plan

**Date:** March 12, 2026  
**Status:** Planning prerequisite  
**Purpose:** Define the staged migration from current CE role identifiers to the canonical federated governance catalog

**Depends On:** `governance_bodies_and_mandates.md`, `rbac_role_permission_matrix.md`, `rbac_policy_coverage_matrix.md`, `live_role_association_inventory_2026-03-11.md`

---

## Summary

This plan covers the identifier migration layer for CE RBAC.

It focuses on:

- current live role identifiers in memberships and invitations
- seed and bootstrap code
- factories and test helpers
- temporary compatibility handling
- the order in which identifiers should be renamed, merged, or retired

This is a migration plan for identifiers and references, not yet the policy refactor itself.

The main design constraint is:

- live CE apps already use `platform_manager`, `community_governance_council`, `community_member`, and some optional specialist roles
- code and tests still heavily assume `platform_manager`
- the migration should not require a one-shot flag day across production data, seeds, bootstrap flows, and the spec suite

---

## Canonical Target Catalog

### Core Platform Roles

| Current identifier | Target identifier | Migration direction |
|--------------------|------------------|---------------------|
| `platform_manager` | `platform_steward` | rename |
| `platform_analytics_viewer` | `analytics_viewer` | rename |

### Core Community Roles

| Current identifier | Target identifier | Migration direction |
|--------------------|------------------|---------------------|
| `community_member` | `community_member` | keep |
| `community_governance_council` | `community_governance_council` | keep |
| `community_facilitator` | `community_organizer` | rename and merge |
| `community_coordinator` | `community_organizer` | rename and merge |

### Optional Specialist Community Roles

| Current identifier | Target identifier | Migration direction |
|--------------------|------------------|---------------------|
| `community_content_curator` | `content_curator` | optional rename |
| `community_contributor` | `contributor` | optional rename |

### Retirement Candidates

Retire unless a live workflow proves otherwise:

- `community_legal_advisor`
- `community_strategist`
- `platform_accessibility_officer`
- `platform_infrastructure_architect`
- `platform_quality_assurance_lead`
- `platform_tech_support`

### Review Separately

- `platform_developer`
  - keep temporarily or replace with permission bundles after code-role audit

---

## Live Data Baseline

From the live inventory:

- `platform_manager` is in use on every included live platform
- `community_governance_council` is in use on every included live platform
- `community_member` is in use on every included live platform
- `community_coordinator` is only in use on `newcomernavigatornl.ca`
- `community_facilitator` is unused on every included live platform in the snapshot
- `platform_analytics_viewer` is only in use on `newcomernavigatornl.ca`
- `newfoundlandlabradoronline` is missing `platform_analytics_viewer` entirely, which indicates schema or seed drift

Migration implication:

- the highest-risk rename is `platform_manager` because it touches all live platforms and much of the code/test suite
- the lowest-risk merge is `community_facilitator` into `community_organizer` because it is unused in the live snapshot
- `community_coordinator` should be migrated carefully because it appears live on one platform and in multiple test helpers and factories

---

## Affected Surface Areas

## 1. Live Membership And Invitation Data

Must migrate references in:

- `better_together_person_platform_memberships.role_id`
- `better_together_person_community_memberships.role_id`
- `better_together_invitations.role_id`
- `better_together_platform_invitations.platform_role_id`
- `better_together_platform_invitations.community_role_id`

This is the production-data migration layer.

## 2. Seed And Bootstrap Code

Known touchpoints:

- `app/builders/better_together/access_control_builder.rb`
- `app/controllers/better_together/setup_wizard_steps_controller.rb`
- any seed tasks/specs that assert `platform_manager` or `platform_analytics_viewer`

The setup wizard currently hard-codes:

- `platform_manager`
- `community_governance_council`

Only the platform-side identifier changes in the first core rename.

## 3. Policy And UI References

Known direct identifier references include:

- `app/policies/better_together/conversation_policy.rb`
- `app/policies/better_together/person_block_policy.rb`
- various views and specs that still check `manage_platform` behavior via platform-manager assumptions

These should not be migrated by search-and-replace alone. They need to move to permission-oriented checks as the policies are refactored.

## 4. Spec Helpers And Test Tags

Known touchpoints:

- `spec/support/automatic_test_configuration.rb`
- `spec/support/better_together/capybara_feature_helpers.rb`
- `spec/support/better_together/devise_session_helpers.rb`
- `spec/support/seed_helper.rb`

The current suite heavily uses:

- `:as_platform_manager`
- `:platform_manager`
- `capybara_login_as_platform_manager`
- `login_as_platform_manager`
- `find_or_create_test_user(..., :platform_manager)`

## 5. Factories And Invitation Test Helpers

Known touchpoints:

- `spec/factories/better_together/users.rb`
- `spec/factories/better_together/community_invitations.rb`
- `spec/factories/better_together/invitations.rb`
- `spec/support/helpers/invitation_test_helpers.rb`

The current test support still creates:

- `:platform_manager`
- `community_coordinator`
- `community_facilitator`

These are explicit migration targets.

---

## Migration Strategy

## Phase 0: Freeze The Canonical Vocabulary

Lock these decisions before migrations:

- `platform_manager` -> `platform_steward`
- `platform_analytics_viewer` -> `analytics_viewer`
- `community_governance_council` stays distinct
- `community_facilitator` and `community_coordinator` merge into `community_organizer`

Do not start data migration until these names are treated as stable.

## Phase 1: Add Canonical Roles In Seeds And Builder

Update `AccessControlBuilder` and related seed flows to create the target identifiers first:

- `platform_steward`
- `analytics_viewer`
- `community_organizer`

At this phase:

- keep legacy identifiers present
- do not delete old roles yet
- make sure target roles receive the canonical permission bundles from `rbac_role_permission_matrix.md`

Purpose:

- allow code and tests to begin migrating without breaking live data or bootstrap

## Phase 2: Introduce Temporary Compatibility Layer

During the migration window:

- accept both legacy and target identifiers in test/setup helpers
- preserve lookup compatibility where specs or bootstrap still request:
  - `platform_manager`
  - `platform_analytics_viewer`
  - `community_coordinator`
  - `community_facilitator`

Recommended compatibility rules:

- factory trait `:platform_manager` may remain temporarily but should assign `platform_steward`
- add new traits/helpers alongside legacy ones:
  - `:platform_steward`
  - `:analytics_viewer`
  - `:community_organizer`
  - `:as_platform_steward`
  - `capybara_login_as_platform_steward`
- legacy helpers should forward to the new canonical roles during transition

Purpose:

- avoid a flag-day spec rewrite

## Phase 3: Migrate Live Data

Run data migrations in production schemas to update memberships and invitation references:

- migrate `platform_manager` memberships and invitation references to `platform_steward`
- migrate `platform_analytics_viewer` references to `analytics_viewer`
- migrate `community_coordinator` and `community_facilitator` references to `community_organizer`

For live apps:

- `community_governance_council` remains unchanged
- `community_member` remains unchanged

Operational rule:

- migrate by role identity mapping, not by role name text
- verify counts before and after for each affected table
- especially verify `newfoundlandlabradoronline`, because it already shows role-catalog drift

## Phase 4: Migrate Seeds, Bootstrap, And Test Helpers

Update:

- setup wizard role assignment
- seed specs
- factory traits
- request/controller/system test auth tags
- invitation helper role creators

Recommended replacements:

| Legacy helper/tag | Target helper/tag |
|-------------------|-------------------|
| `:as_platform_manager` | `:as_platform_steward` |
| `:platform_manager` | `:platform_steward` |
| `capybara_login_as_platform_manager` | `capybara_login_as_platform_steward` |
| `login_as_platform_manager` | `login_as_platform_steward` |

And for invitation/community test helpers:

| Legacy helper | Target helper |
|---------------|---------------|
| `make_community_coordinator` | `make_community_organizer` |
| `ensure_community_coordinator_role_with_permissions` | `ensure_community_organizer_role_with_permissions` |
| `ensure_community_facilitator_role_with_permissions` | remove or alias temporarily to organizer |

## Phase 5: Remove Legacy Identifier Dependencies

Only after data migration, seed migration, and policy refactor:

- remove legacy role creation from the builder
- remove fallback helper aliases
- remove spec references to legacy role tags and traits
- retire unused identifiers from seeds and docs

---

## Detailed Identifier Plan

## `platform_manager` -> `platform_steward`

### Why First

- live on every included platform
- hard-coded in setup wizard, factories, policies, specs, helpers, and seed specs
- central to the old RBAC mental model

### Data Migration Scope

- platform memberships
- platform invitations
- generic references in invitation/preview/test records where role is platform-scoped

### Code Migration Scope

- seed builder
- setup wizard
- conversation policy helper logic
- person-block policy special casing
- test auth helpers and metadata tags
- user factory trait
- request/controller/system specs

### Compatibility Rule

During migration:

- `:platform_manager` trait may create a `platform_steward` membership under the hood
- `:as_platform_manager` may alias to `:as_platform_steward`

## `platform_analytics_viewer` -> `analytics_viewer`

### Migration Risk

- limited live footprint
- broader spec and metrics-doc footprint than live-data footprint

### Data Migration Scope

- metrics-related platform memberships where present
- invitation rows where present

### Code Migration Scope

- metrics policy specs
- seed specs
- mailer previews
- request specs checking analytics role access

## `community_facilitator` + `community_coordinator` -> `community_organizer`

### Migration Risk

- live `community_facilitator` footprint is zero in the snapshot
- live `community_coordinator` footprint exists on `newcomernavigatornl.ca`
- both are used in invitation factories and test helpers

### Data Migration Scope

- community memberships
- invitation rows
- platform invitation `community_role_id` references

### Code Migration Scope

- invitation test helpers
- invitation factories
- policy specs using coordinator/facilitator assumptions

### Compatibility Rule

During migration:

- both legacy identifiers should resolve to `community_organizer` behavior in test helpers

## `community_governance_council`

### Decision

- keep as-is for now

### Reason

- live on every included platform
- represents formal governance rather than day-to-day operations
- should not be collapsed into organizer language

### Migration Work

- no identifier rename in the first migration wave
- still needs policy/permission cleanup to distinguish it from `community_organizer`

---

## Production Migration Checklist

For each live platform:

1. confirm target roles exist
2. count old-role references in memberships and invitation tables
3. migrate rows to target role ids
4. verify counts by table and identifier after migration
5. verify host platform membership and host community governance membership are intact
6. verify invitation creation and acceptance still work

Special attention:

- `newfoundlandlabradoronline`
  - confirm role catalog drift before running identifier migration
  - add missing target roles before remapping any rows

---

## Test Suite Migration Checklist

1. add canonical traits and auth helpers
2. keep legacy aliases temporarily
3. migrate request/controller/system metadata tags
4. migrate policy specs and factories
5. migrate invitation helper methods
6. remove legacy aliases only after the suite is green on canonical names

High-volume touchpoints include:

- `spec/support/automatic_test_configuration.rb`
- `spec/support/better_together/capybara_feature_helpers.rb`
- `spec/support/better_together/devise_session_helpers.rb`
- `spec/factories/better_together/users.rb`
- `spec/support/helpers/invitation_test_helpers.rb`

---

## Acceptance Criteria

- every target identifier has a defined migration rule
- live memberships and invitations can be remapped without ambiguity
- bootstrap/setup flows assign canonical identifiers
- the test suite has a compatibility path during transition
- legacy identifiers can be removed only after data, seed, and helper migration are complete

