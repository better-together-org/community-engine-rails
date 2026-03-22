# Schema-Per-Platform And Federated Network Implementation Plan

**Version:** 3.0  
**Date:** March 11, 2026  
**Status:** Planning baseline  
**Depends On:** `tenant_data_ownership_matrix.md`, `tenant_runtime_contract.md`, `governance_bodies_and_mandates.md`, `rbac_role_permission_matrix.md`, `federated_rbac_reassessment_and_coverage_plan.md`

---

## Executive Summary

Implement a hybrid architecture for Community Engine:

- locally hosted CE platforms on this server use one PostgreSQL schema per platform
- each platform keeps its own local accounts, people, memberships, onboarding, and private communities
- CE-powered platforms can authenticate against one another through OAuth
- linked platform accounts create one layer of the network graph
- platform-manager-configured peer/member platform relationships create another layer
- content sharing is private by default, opt-in, agreement-backed, mirrored locally, and may support bi-directional sync

This plan replaces the earlier identity-split direction that treated users as host-global and people as tenant-local. The new architecture preserves local platform autonomy and uses federation rather than a host-wide account model.

---

## Target Architecture

### Local Hosting Model

- each locally hosted platform has one tenant schema
- `public` stores local platform routing metadata and external peer platform records
- each tenant schema stores the platform’s local accounts, people, communities, content, memberships, and settings

### Federated Network Model

- CE platforms can act as OAuth providers and clients for one another
- local accounts can be linked to remote platform accounts
- accepted person/community/platform connections form a network graph
- platform managers can configure peer/member platform relationships and content-sharing rules
- mirrored content from authorized peer platforms can appear in local network feeds and search

### Consent Model

- agreements govern shared authentication scopes, mirrored content permissions, and publication rights
- connection request acceptance creates the relationship edge and activates any required agreement-backed consent

---

## Architecture Decisions Locked By This Plan

### Decision 1: Local Account Ownership

Each platform owns its own local `User`, `Person`, memberships, and onboarding. Federated sign-in does not eliminate local account creation; it accelerates and links it.

### Decision 2: OAuth-Based Federation

CE-to-CE OAuth is the standard mechanism for:

- social login between CE platforms
- linked account establishment
- API access for mirroring and publish-back workflows

### Decision 3: Shared Connection Primitive

`ConnectionRequest` is implemented as a subtype of `Joatu::Request` and is used for person, community, and platform connection workflows.

### Decision 4: Private-By-Default Networking

Platforms start private. Sharing content with peer platforms requires explicit opt-in and agreement-backed consent.

### Decision 5: Mirrored Network Content

Authorized remote content is mirrored locally with source metadata and sync state. Bi-directional sync requires mutual authorization on both platforms.

---

## Workstreams

## Workstream 0: Planning Prerequisites

Complete before code implementation:

- confirm the ownership matrix
- confirm the federated runtime contract
- confirm the governance bodies and mandates
- confirm the RBAC role and permission matrix
- confirm the federated RBAC redesign and coverage plan
- map existing OAuth, integrations, agreements, and Joatu request primitives to the new model
- record any deviations from the planning defaults as ADRs

Acceptance criteria:

- no major model family lacks a target ownership class
- federation, tenancy, agreements, and mirroring use one coherent vocabulary
- governance bodies and role identifiers are defined before authorization migration starts
- role-permission boundaries are defined before federation or policy refactor starts
- federation-sensitive actions have an explicit authorization plan instead of relying on `manage_platform`

## Workstream 0A: RBAC Cleanup And Coverage Audit

Complete before Workstreams 2 through 7:

- streamline the seeded role catalog
- rename canonical roles so role names describe responsibility, not model names
- add federation and mirrored-content permission families
- audit policy coverage across platform, community, content, OAuth, Joatu, messaging, safety, and metrics domains
- identify placeholder or under-specified policies and replace them with explicit action matrices

Acceptance criteria:

- platform connection approval, OAuth trust, mirrored-content ingestion, and publish-back each have explicit permissions
- redundant platform-specialist roles are retired or deprecated
- mirrored-content policies distinguish local moderation from remote canonical ownership
- high-risk policy domains have policy specs and request or system coverage

## Workstream 1: Public Platform Registry And Routing

Extend `public.better_together_platforms` to support:

- local hosted platform routing and schema metadata
- external peer platform records
- trust, privacy, and sharing defaults
- pre-seeded host-platform connection bootstrap

Acceptance criteria:

- local hosted platforms and external peer platforms can coexist in the same registry
- host resolution for local tenants remains unambiguous

## Workstream 2: CE OAuth Federation

Implement CE-to-CE OAuth provider/client behavior for:

- federated sign-in
- linked account establishment
- scoped API access for sync and publishing

Acceptance criteria:

- one CE platform can authenticate a user for another CE platform
- peer platform OAuth scopes can be constrained by agreements and platform policy
- existing invitation and onboarding gates are still enforced locally
- OAuth trust configuration is restricted by explicit federation permissions, not generic platform admin alone

## Workstream 3: Local Join And Account Link Flow

Add the local admission flow for federated sign-in:

- authenticate through peer CE OAuth
- determine whether a local account and person exist
- if not, prompt the user to join locally
- enforce invitation-only rules, onboarding wizards, and agreements before participation
- create the local account/person and the cross-platform linkage once admitted

Acceptance criteria:

- federated auth never bypasses local participation rules
- linked accounts are visible and manageable by the user and the platform where appropriate

## Workstream 4: Connection Requests And Relationship Graph

Implement `ConnectionRequest` on top of `Joatu::Request` and define accepted connection edges for:

- person-to-person
- person-to-community
- community-to-community
- platform-to-platform

Acceptance criteria:

- all four connection types use the same request primitive
- acceptance creates the relationship edge and any associated agreement state
- personal-community participation can use the same connection model
- platform-to-platform connection approval is governed by explicit network permissions

## Workstream 5: Agreements And Consent

Extend agreement usage to cover:

- shared authentication consent
- content mirroring consent
- publish-back or bi-directional sync consent
- platform-manager sharing terms

Acceptance criteria:

- no mirrored or publish-back flow runs without agreement-backed authorization where required
- agreement state can be audited and revoked

## Workstream 6: Mirrored Content And Network Feed

Implement the local mirror model for peer platform content:

- ingest authorized remote content into local mirror records
- retain source attribution and sync metadata
- refresh mirrors regularly
- support local feed and search over native plus mirrored content
- support optional publish/update back to peers when both sides allow it

Acceptance criteria:

- mirrored content is attributable, refreshable, and permission-aware
- local network feed composition reflects platform-manager configuration plus linked-account relevance
- sync failures do not corrupt canonical source ownership

## Workstream 7: Platform-Manager Network Controls

Add manager-facing controls for:

- peer/member platform connections
- inbound and outbound platform requests
- sharing settings and visibility
- sync health and mirror review

Acceptance criteria:

- platform managers can see and control what enters the network feed
- platform managers can approve, deny, or revoke sharing relationships

## Workstream 8: Local Tenancy Operations

Implement the local tenancy operations needed for hosted platforms:

- schema provisioning
- migration execution across local platforms
- backup and restore
- sync diagnostics
- fleet-admin oversight of locally hosted tenants

Acceptance criteria:

- local hosted platforms can be provisioned and operated independently
- federation features do not require abandoning local schema isolation

---

## Domain-Specific Migration Notes

| Domain | Migration Concern |
|--------|-------------------|
| local account model | keep platform-local accounts while layering federated auth and linked accounts on top |
| platform registry | distinguish local hosted platforms from external peers cleanly |
| Joatu requests | add connection subtype without breaking existing request/offer/agreement semantics |
| agreements | extend to cover auth and content-sharing consent without overloading existing exchange flows beyond repair |
| mirrored content | define canonical local mirror schema and source attribution |
| search and feed | combine native and mirrored content without erasing source platform boundaries |

---

## Testing Strategy

### Unit Tests

- platform registry behavior for local and external platforms
- CE OAuth provider/client scope rules
- connection-request subtype validation and acceptance behavior
- agreement activation rules for auth and sharing consent
- mirror ingest and sync-state transitions

### Integration Tests

- federated sign-in to a second CE platform
- invitation-required local join after federated auth
- onboarding-required local join after federated auth
- person/community/platform connection request flows
- mirrored content ingest and refresh
- opt-in publish-back flow between consenting platforms

### Security Tests

- federated auth cannot bypass local invitation/onboarding restrictions
- mirrored content never appears without source platform authorization
- bi-directional sync never runs without mutual consent
- remote platform outage or revoked token fails safely
- local private spaces stay local unless explicitly exposed through allowed network flows

---

## Rollout Sequence

1. Approve the ownership matrix and runtime contract.
2. Extend the platform registry for local hosted and external peer platforms.
3. Add CE OAuth provider/client capabilities and linked-account flows.
4. Add `ConnectionRequest` and accepted connection edge models.
5. Extend agreements for auth and content-sharing consent.
6. Build mirrored content ingest, refresh, and publish-back workflows.
7. Add platform-manager network controls and feed configuration.
8. Finish local tenancy operations for provisioning, backup, restore, and sync diagnostics.

---

## Success Criteria

- each locally hosted platform remains autonomous in accounts, onboarding, and community governance
- CE-powered platforms can authenticate users for one another through OAuth
- linked platform accounts and configured platform connections both contribute to the network graph
- private-by-default sharing is enforced
- mirrored content is consent-backed, attributable, and refreshable
- local schema isolation and federated networking coexist without collapsing into one global account store

---

## Related Documents

- `docs/assessments/multi_tenancy_gap_assessment_2026-03-11.md`
- `docs/implementation/multi_tenancy/tenant_data_ownership_matrix.md`
- `docs/implementation/multi_tenancy/tenant_runtime_contract.md`
