# RBAC Role Permission Matrix

**Date:** March 12, 2026  
**Status:** Planning prerequisite  
**Purpose:** Define the canonical CE role catalog, permission families, and scope boundaries for federated CE platforms

**Depends On:** `governance_bodies_and_mandates.md`

---

## Summary

This document converts the governance-body model into an implementation-ready RBAC matrix.

It defines:

- the canonical role identifiers to support in CE
- the permission families each role should hold
- the scope where those permissions apply
- the boundaries between platform stewardship, community governance, community operations, asset stewardship, and safety/accountability
- the additional constraints required for federation and mirrored content

This document is the authorization source of truth between:

- governance design
- policy refactor
- role and invitation migration
- federated platform implementation

---

## Design Rules

1. Roles describe responsibility, not model names.
2. Permissions describe capabilities, not titles.
3. The joinable resource determines scope.
4. Federation actions must not be implied by generic platform-editing authority.
5. Mirrored-content actions must distinguish local moderation from canonical source ownership.
6. Asset stewardship and safety/accountability remain separate from ordinary platform stewardship.

---

## Canonical Role Catalog

### Platform Scope

These roles are assigned through `PersonPlatformMembership`.

| Role identifier | Purpose | Status |
|-----------------|---------|--------|
| `platform_steward` | Governs the platform as shared infrastructure and federated node | canonical |
| `network_admin` | Manages platform connections, OAuth trust, mirroring, and publish-back | canonical |
| `analytics_viewer` | Read-only metrics and reporting access | canonical |
| `platform_asset_steward` | Stewards platform-scoped assets and procedures | canonical |
| `infrastructure_steward` | Stewards deployment, storage, domains, backups, and related infrastructure | canonical |
| `records_steward` | Stewards records, inventories, documentation, and procedural continuity | canonical |
| `platform_safety_steward` | Handles platform-wide safety cases, blocks, and escalation | canonical |
| `support_admin` | Handles support and account-assistance workflows without full federation control | canonical |

### Community Scope

These roles are assigned through `PersonCommunityMembership`.

| Role identifier | Purpose | Status |
|-----------------|---------|--------|
| `community_member` | Baseline community participation | canonical |
| `community_governance_council` | Formal community decision-making body | canonical |
| `community_organizer` | Day-to-day community operations and coordination | canonical |
| `community_asset_steward` | Stewards community-scoped assets and procedures | canonical |
| `community_safety_steward` | Handles community safety, moderation escalation, and reports | canonical |
| `content_curator` | Curates community content and featured items | optional |
| `contributor` | Elevated content contribution role where needed | optional |

### Transition Guidance

| Current identifier | Target identifier | Direction |
|--------------------|------------------|-----------|
| `platform_manager` | `platform_steward` | rename |
| `platform_analytics_viewer` | `analytics_viewer` | rename |
| `community_facilitator` | `community_organizer` | rename and merge |
| `community_coordinator` | `community_organizer` | rename and merge |
| `community_governance_council` | `community_governance_council` | keep |
| `community_member` | `community_member` | keep |
| `community_content_curator` | `content_curator` | optional rename |
| `community_contributor` | `contributor` | optional rename |

Roles not in the canonical catalog should be retired unless a live workflow demonstrates a durable need for them.

---

## Permission Families

### Platform Stewardship

- `view_platform`
- `edit_platform`
- `manage_platform_settings`
- `manage_platform_members`
- `manage_platform_roles`

### Federation And Network

- `view_network`
- `manage_network_connections`
- `approve_network_connections`
- `manage_federation_auth`
- `manage_content_sharing`
- `manage_mirrors`
- `publish_to_network`
- `review_sync_failures`

### Community Governance And Operations

- `view_community`
- `edit_community`
- `manage_community_members`
- `manage_community_roles`
- `manage_community_content`
- `invite_members`

### Content And Experience

- `create_content`
- `edit_content`
- `moderate_content`
- `feature_content`
- `manage_navigation`
- `manage_templates`

### Asset Stewardship

- `manage_platform_assets`
- `manage_community_assets`
- `manage_infrastructure_assets`
- `manage_records`
- `view_operational_diagnostics`

### Safety And Accountability

- `view_safety_cases`
- `manage_safety_cases`
- `manage_person_blocks`
- `review_reports`

### Metrics And Reporting

- `view_metrics`
- `create_reports`
- `download_reports`

---

## Role Matrix

### Platform Roles

| Role | Scope | Core permissions | Explicit limits |
|------|-------|------------------|-----------------|
| `platform_steward` | platform | `view_platform`, `edit_platform`, `manage_platform_settings`, `manage_platform_members`, `manage_platform_roles`, `view_network` | does not automatically get `manage_federation_auth`, `approve_network_connections`, or `publish_to_network` |
| `network_admin` | platform | `view_network`, `manage_network_connections`, `approve_network_connections`, `manage_federation_auth`, `manage_content_sharing`, `manage_mirrors`, `publish_to_network`, `review_sync_failures` | does not automatically govern community membership or community internal policy |
| `analytics_viewer` | platform | `view_metrics`, `create_reports`, `download_reports` | no write authority outside reporting |
| `platform_asset_steward` | platform | `manage_platform_assets`, `view_operational_diagnostics` | no automatic federation, membership, or safety authority |
| `infrastructure_steward` | platform | `manage_infrastructure_assets`, `view_operational_diagnostics` | no automatic community or network authority |
| `records_steward` | platform | `manage_records`, `view_operational_diagnostics` | no automatic federation or moderation authority |
| `platform_safety_steward` | platform | `view_safety_cases`, `manage_safety_cases`, `manage_person_blocks`, `review_reports` | no automatic platform policy, network, or content-publishing authority |
| `support_admin` | platform | `view_platform`, limited `manage_platform_members`, limited `review_reports` where support workflow requires it | no federation, role-management, or broad policy authority |

### Community Roles

| Role | Scope | Core permissions | Explicit limits |
|------|-------|------------------|-----------------|
| `community_member` | community | `view_community`, baseline content participation through non-RBAC checks | no role, governance, or moderation authority by default |
| `community_governance_council` | community | `view_community`, `edit_community`, `manage_community_members`, `manage_community_roles`, `manage_community_content`, `invite_members` | no platform federation or infrastructure authority |
| `community_organizer` | community | `view_community`, `edit_community`, `manage_community_content`, `invite_members` | no final governance authority unless separately delegated |
| `community_asset_steward` | community | `manage_community_assets` | no automatic governance or federation authority |
| `community_safety_steward` | community | `view_safety_cases`, `manage_safety_cases`, `review_reports` in community context | no automatic platform-wide safety or network authority |
| `content_curator` | community | `feature_content`, limited `manage_community_content` | no governance or membership authority |
| `contributor` | community | `create_content`, limited `edit_content` for delegated workflows | no governance or moderation authority |

---

## Federation Boundary Rules

### Platform Connections

Creating, approving, revoking, or configuring platform-to-platform connections requires:

- `network_admin`
- or a scoped delegation from `platform_steward` if the product later supports delegated capability grants

`platform_steward` alone should not automatically imply federation power.

### OAuth Trust

Managing CE-to-CE OAuth provider/client trust requires:

- `manage_federation_auth`
- active platform-scope authority

This must not be bundled implicitly into ordinary platform editing.

### Sharing And Mirroring

Enabling inbound or outbound content sharing requires:

- `manage_content_sharing`
- any required active agreement state

Refresh, re-sync, or publish-back requires:

- `manage_mirrors` or `publish_to_network`
- valid agreement and sharing policy

---

## Mirrored Content Matrix

Mirrored content is local content with remote provenance.

Base rule:

- source platform retains canonical ownership
- local platform controls local visibility, local placement, and local moderation of the mirror
- publish-back requires both local RBAC and remote authorization

| Action | Community member | Community organizer | Community governance council | Platform steward | Network admin | Source platform |
|--------|------------------|---------------------|------------------------------|------------------|---------------|-----------------|
| view surfaced mirror | yes | yes | yes | yes | yes | yes |
| feature/hide in community context | no | yes, local context only | yes, local context only | yes | yes | n/a |
| moderate local mirror | no | limited, local context only | yes, local context only | yes | yes | n/a |
| edit canonical source content | no | no | no | no | no by default | yes |
| trigger refresh or re-sync | no | no | no | optional | yes | yes |
| approve inbound mirroring policy | no | no | no | optional | yes | yes |
| approve publish-back | no | no | no | optional | yes | yes |
| revoke sharing relationship | no | no | no | optional | yes | yes |

If a local platform wants `platform_steward` to share these powers by default, that should be a deliberate override in seeds and policy, not the baseline.

---

## Invitations, Memberships, And Requests

### Platform Membership And Invitations

- `platform_steward` manages ordinary platform membership and role assignment
- `network_admin` is not automatically a platform-membership manager unless separately granted
- invitation flows for platform stewardship should be auditable and distinct from community membership invitations

### Community Membership And Invitations

- `community_governance_council` manages formal community membership and role assignment
- `community_organizer` may invite or onboard members where delegated
- the host community should preserve its distinction from platform membership even when there is large person overlap

### Connection Requests

Person, community, and platform connection requests should use the same request primitive, but authorization differs by source and target type:

- person-to-person: ordinary participation and consent rules
- person-to-community: community-level invitation/admission rules
- community-to-community: community governance authority
- platform-to-platform: `network_admin` authority

---

## Policy Refactor Guidance

Policies should stop treating `manage_platform` as a universal bypass.

The preferred authorization order is:

1. verify the actor’s scoped role membership
2. verify the capability needed for the action
3. verify record scope and provenance
4. verify any agreement, sharing, or sync-state preconditions

High-risk policy domains that need explicit action matrices:

- platform connections
- OAuth applications and trust configuration
- Joatu requests and connection acceptance
- platform memberships and invitations
- community memberships and invitations
- mirrored content
- moderation and safety
- metrics and exports

---

## Acceptance Criteria

- every canonical role has a defined scope and core permission set
- federation permissions are separate from ordinary platform editing
- community governance remains distinct from community operations
- mirrored-content authorization distinguishes local moderation from remote ownership
- invitation and membership governance is defined at both platform and community levels
- this matrix can be mapped directly into `Role`, `ResourcePermission`, policies, and test helpers

