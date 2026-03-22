# Federated RBAC Reassessment And Coverage Plan

**Date:** March 11, 2026  
**Status:** Planning prerequisite  
**Purpose:** Redesign CE authorization for schema-per-platform tenancy, federated platform connections, and mirrored content

**Depends On:** `governance_bodies_and_mandates.md`, `rbac_role_permission_matrix.md`

---

## Summary

CE already has a real RBAC foundation:

- `Role`
- `ResourcePermission`
- `PersonPlatformMembership`
- `PersonCommunityMembership`
- Pundit policies

That foundation is not yet shaped for federated platform networking.

Current evidence from `AccessControlBuilder`, policy code, and specs shows:

- `platform_manager` remains the dominant platform-wide authority
- many platform roles are seeded but appear redundant or unused in day-to-day policy flows
- many policies still treat `manage_platform` as a broad bypass
- policy coverage is uneven: 76 policy files, about 30 policy specs
- request and feature tests heavily assume `:as_platform_manager`
- several policies are placeholders or near-placeholders, including `MessagePolicy`

Federation and mirrored content should not be built on top of that without a cleanup pass.

The canonical role-and-permission source for that cleanup is now:

- `rbac_role_permission_matrix.md`

This document defines the required RBAC redesign and audit work before implementing:

- platform-to-platform connections
- CE-to-CE OAuth trust management
- mirrored-content moderation and publish-back
- federated account linking

---

## Current-State Findings

### Existing Authority Shape

- `Role` and `ResourcePermission` are reusable and worth keeping.
- `AccessControlBuilder` seeds a large catalog of platform and community roles.
- The seeded platform catalog is wider than the permissions currently exercised by policy and tests.
- The current policy layer often relies on `manage_platform` or `update_platform` instead of narrower capability families.

### Evidence That Cleanup Is Needed

- `AccessControlBuilder` seeds platform roles such as `platform_infrastructure_architect`, `platform_tech_support`, `platform_developer`, `platform_quality_assurance_lead`, and `platform_accessibility_officer`, but their seeded permission sets are nearly identical.
- Request specs and support helpers overwhelmingly default to `platform_manager`.
- Some authorization code uses capability checks, some compares role identity directly, and some still uses ownership shortcuts.
- Several policy files are stubs or effectively inherit defaults without a complete action matrix.

### Why Federation Raises The Bar

Federation introduces actions that are more sensitive than ordinary platform editing:

- approving a peer platform connection
- authorizing OAuth trust
- enabling mirrored content ingestion
- moderating a mirror locally
- allowing publish-back to the source platform
- revoking sync or consent

Those actions should not be covered by a generic "manage the platform" permission.

---

## Design Goals

1. Keep the existing RBAC primitives, but streamline the catalog.
2. Rename roles so role names describe responsibility, not model names.
3. Move model specificity into permissions and policy context.
4. Separate local platform administration from federation and network administration.
5. Make mirrored-content actions provenance-aware.
6. Audit coverage across CE models, controller actions, and UI affordances.

---

## Target Role Catalog

The role catalog and permission families below are now subordinate to `rbac_role_permission_matrix.md`.
If this document and the matrix differ, the matrix wins.

This section should now be read as subordinate to `governance_bodies_and_mandates.md`.
If the two documents conflict, the governance-bodies document wins.

### Platform-Level Roles

These roles live through `PersonPlatformMembership`.

| Current Direction | Proposed Canonical Role | Notes |
|-------------------|-------------------------|-------|
| `platform_manager` | `platform_steward` | Full local platform stewardship for the node, but not automatic federation god-mode |
| `platform_analytics_viewer` | `analytics_viewer` | Narrow reporting role |
| redundant specialized platform roles | retire or replace with permissions | Current seeded platform-specialist roles are too overlapping to justify distinct seeds |
| new | `network_admin` | Manages platform connections, OAuth trust, sharing policies, mirroring, publish-back |
| new | `safety_admin` | Handles platform-wide safety, blocks, reports, cases |
| new | `support_admin` | Handles support and user-management flows without inheriting all network powers |

### Community-Level Roles

These roles live through `PersonCommunityMembership`.

| Current Direction | Proposed Canonical Role | Notes |
|-------------------|-------------------------|-------|
| `community_member` | `community_member` | Baseline participation remains distinct for now |
| `community_facilitator` | `community_organizer` | Operational role; may merge with coordinator |
| `community_coordinator` | `community_organizer` | Operational role; may merge with facilitator |
| `community_governance_council` | `community_governance_council` | Keep distinct as formal community governance body |
| current niche community specialist roles | retire or convert to permissions | Keep catalog compact unless a workflow truly needs a named standing role |

### Role Naming Rule

Roles should be named by responsibility:

- `network_admin`
- `platform_steward`
- `community_governance_council`
- `community_organizer`
- `community_member`

The joinable context already tells us whether the role is platform-level or community-level.

### Recommended Identifier Migration Map

This is the current recommendation for identifier cleanup, based on live usage and the goal of simpler, more durable names:

| Current identifier | Recommended identifier | Direction |
|--------------------|------------------------|-----------|
| `platform_manager` | `platform_steward` | rename |
| `platform_analytics_viewer` | `analytics_viewer` | rename |
| `community_member` | `community_member` | keep for now |
| `community_facilitator` | `community_organizer` | rename and merge |
| `community_coordinator` | `community_organizer` | rename and merge |
| `community_governance_council` | `community_governance_council` | keep distinct |
| `community_contributor` | `contributor` | optional rename if kept |
| `community_content_curator` | `content_curator` | optional rename if kept |
| `community_legal_advisor` | retire unless a real standing workflow requires it | retire |
| `community_strategist` | retire unless a real standing workflow requires it | retire |
| `platform_accessibility_officer` | retire or replace with permissions | retire |
| `platform_infrastructure_architect` | retire or replace with permissions | retire |
| `platform_quality_assurance_lead` | retire or replace with permissions | retire |
| `platform_tech_support` | retire or replace with permissions | retire |
| `platform_developer` | keep temporarily or collapse into permissions | review |

The most immediate practical rename is:

- `platform_manager` -> `platform_steward`

The strongest non-platform consolidation candidate is:

- `community_facilitator` -> `community_organizer`
- `community_coordinator` -> `community_organizer`

That recommendation is stronger than the others because live data shows:

- `community_governance_council` is used on every included live platform
- `community_facilitator` is unused on every included live platform in the snapshot
- `community_coordinator` is only used on one included live platform

That makes `community_organizer` a better canonical identifier for operational community leadership without erasing the distinct governance-body role.

---

## Target Permission Families

These permission families are defined normatively in `rbac_role_permission_matrix.md`.
This section remains as a summary checklist for the reassessment and coverage audit.

### Platform Administration

- `view_platform`
- `edit_platform`
- `manage_platform_settings`
- `manage_platform_members`
- `manage_platform_roles`
- `manage_platform_safety`

### Federation And Network Administration

- `view_network`
- `manage_network_connections`
- `approve_network_connections`
- `manage_federation_auth`
- `manage_content_sharing`
- `manage_mirrors`
- `publish_to_network`
- `review_sync_failures`

### Community Administration

- `view_community`
- `edit_community`
- `manage_community_members`
- `manage_community_roles`
- `manage_community_content`
- `invite_members`

### Content Administration

- `create_content`
- `edit_content`
- `moderate_content`
- `feature_content`
- `manage_navigation`
- `manage_templates`

### Metrics And Reporting

- `view_metrics`
- `create_reports`
- `download_reports`

### Safety And Moderation

- `view_safety_cases`
- `manage_safety_cases`
- `manage_person_blocks`
- `review_reports`

Permission identifiers should stay capability-oriented. The policy or record context should decide whether the capability applies to a platform, community, native record, or mirrored record.

---

## Mirrored Content Authorization Contract

The normative mirrored-content action matrix now lives in `rbac_role_permission_matrix.md`.
This section remains as design rationale for the reassessment work.

Mirrored records remain local copies of content whose canonical source may be a different platform.

The policy layer must distinguish:

- native content: `record.platform_id == Current.platform.id`
- mirrored content: `record.platform_id != Current.platform.id`

### Default Rule

- the source platform remains canonical owner
- the local platform controls local visibility and local moderation of its mirror
- publish-back requires both local permission and agreement-backed remote authorization

### Action Matrix

| Action | Ordinary Member | Community Organizer | Platform Admin | Network Admin | Source Platform |
|--------|-----------------|--------------------|----------------|---------------|-----------------|
| view mirrored content | yes, if surfaced locally | yes | yes | yes | yes |
| feature/hide locally | no | community-context only | yes | yes | n/a |
| moderate local mirror | no | community-context only | yes | yes | n/a |
| edit canonical remote content | no | no | no | no by default | yes |
| trigger refresh/re-sync | no | no | optional | yes | yes |
| approve publish-back | no | no | optional | yes | yes |
| revoke mirrored sharing | no | no | optional | yes | yes |

### Policy Rule

Mirrored-content policies should evaluate:

1. local RBAC
2. local visibility / community context
3. mirror provenance and sync state
4. active agreement and sharing policy

A positive local permission alone is not enough for cross-platform actions.

---

## Platform Connection Authorization Contract

Platform connections and OAuth trust should be treated as platform-governance actions, not generic settings edits.

### Required Capability Boundaries

- creating or responding to a platform connection request requires `manage_network_connections`
- approving a platform connection requires `approve_network_connections`
- configuring OAuth trust, scopes, keys, or client behavior requires `manage_federation_auth`
- enabling mirrored content or publish-back requires `manage_content_sharing`
- running or repairing sync requires `manage_mirrors` or `review_sync_failures`

### Default Role Mapping

- `platform_admin`: local platform admin powers, optionally some read-only network visibility
- `network_admin`: full network and federation powers
- `support_admin`: no connection approval by default

---

## Coverage Audit Scope

The RBAC audit must cover policy presence, action coverage, and effective enforcement.

### Domains To Audit

| Domain | Audit Focus |
|--------|-------------|
| Platform | platform settings, memberships, invitations, dashboard, OAuth apps, webhooks |
| Community | CRUD, membership management, invitations, navigation, integrations |
| Person / User | profile visibility, support access, blocks, linked accounts |
| Content | pages, posts, blocks, templates, navigation, uploads |
| Events | events, calendars, invitations, attendance |
| Conversations | conversations, messages, participant rules |
| Joatu | requests, offers, agreements, future `ConnectionRequest` |
| Safety | cases, actions, notes, reports, person blocks |
| Metrics | dashboard, reports, downloads |
| Federation | platform connections, OAuth trust, mirrors, sync, publish-back |

### Coverage Questions For Each Model

1. Does the model have a policy?
2. Are all controller and UI actions mapped to policy methods?
3. Are scopes implemented and non-trivial?
4. Does the policy use permissions, role identity, ownership shortcuts, or no check at all?
5. Does the model need instance-scoped permissions?
6. Does the model need mirrored-content or federation-aware rules?
7. Does the model have policy specs and request/system coverage?

### Initial High-Risk Targets

- `PlatformPolicy`
- `PersonPlatformMembershipPolicy`
- `ConversationPolicy`
- `MessagePolicy`
- `PersonPlatformIntegrationPolicy`
- OAuth application and webhook policies
- future platform-connection and mirrored-content policies

---

## Streamlining Rules

1. Remove seeded roles whose permission bundles are identical or near-identical.
2. Prefer one narrow role plus explicit permissions over many decorative role names.
3. Stop using role identifiers directly in policies unless the rule is truly role-identity based.
4. Prefer `permitted_to?` over bespoke role lookups where possible.
5. Add explicit scopes to policies that currently inherit trivial or empty scope behavior.
6. Require policy specs for every non-trivial policy and request/system coverage for sensitive flows.

---

## Implementation Sequence

### Phase 1: Inventory And Mapping

- inventory seeded roles and permissions from `AccessControlBuilder`
- classify each role as keep, rename, merge, or retire
- map current policy checks to permission families

### Phase 2: Catalog Cleanup

- rename canonical roles
- introduce compatibility aliases or migration mapping for renamed identifiers
- add federation/network permission families
- remove or deprecate redundant seeded roles
- add compatibility mapping for existing fixtures and seeds during transition

### Phase 3: Policy Refactor

- replace broad `manage_platform` bypasses where narrower permissions are needed
- refactor policies that directly inspect role identifiers
- add provenance-aware logic for mirrored records
- add platform-connection and sync policy classes

### Phase 4: Coverage Audit

- produce a model-by-model matrix of policy methods, scopes, controller actions, and spec coverage
- fill missing policy specs first for high-risk domains
- add request/system coverage for mirrored-content and network-admin workflows

---

## Acceptance Criteria

- no federation-sensitive action depends only on `manage_platform`
- platform connection approval, OAuth trust, mirrored-content ingestion, and publish-back each have explicit permissions
- role names no longer encode model names unless the role is deliberately stakeholder-facing
- redundant platform-specialist seed roles are removed or deprecated
- all high-risk models have explicit non-placeholder policies and policy specs
- mirrored-content actions distinguish local moderation from canonical remote ownership

---

## Immediate Follow-On Deliverable

Before code changes begin for federation, CE should produce a compact audit matrix documenting:

- model
- policy file
- scope quality
- permission family used
- spec coverage
- federation impact
- remediation priority

That matrix should become the implementation checklist for the RBAC cleanup workstream.
