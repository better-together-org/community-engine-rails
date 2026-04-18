# Federation Registry And Tenant Boundary

**Date:** April 5, 2026  
**Status:** Architecture reconciliation baseline  
**Purpose:** Define how federation, mirrored content, linked accounts, and private sharing interact with the public platform registry and per-platform tenant schemas

---

## Why this document exists

Community Engine's intended platform model now has two strong requirements that must both remain true:

1. **platform-owned private/local data belongs in each platform schema**
2. **platform-to-platform federation must still work across those schemas**

Without a clear boundary, federation features can quietly become a reason to keep private data in shared tables. This document defines the opposite rule:

- federation is a **network layer between platforms**
- federation is **not** a license to collapse platform-local ownership

It complements:

- `infrastructure_app_platform_topology.md`
- `platform_registry_and_schema_boundary.md`
- `platform_runtime_execution_contract.md`
- `platform_schema_migration_map.md`
- `tenant_data_ownership_matrix.md`
- `federated_seed_and_sync_handoff_2026-03-12.md`

---

## Executive summary

### The core rule

Federation should pass **through** the public platform registry/gateway layer, while leaving platform-private working data inside each platform schema.

### What belongs to the public/network layer

- platform registry records
- platform connections
- federation access tokens
- connection/bootstrap/trust metadata
- cross-platform agreement and sync contracts that identify participating platforms

### What belongs to platform schemas

- local users and people
- local communities and memberships
- local content and moderation state
- local messaging and private spaces
- local safety records
- local mirrored-content projections used for local feed/search/display

### What needs careful hybrid handling

- `PersonLink`
- `PersonAccessGrant`
- `PersonLinkedSeed`
- mirrored content provenance and refresh state
- agreement-backed publish-back and linked-content access

These are cross-platform by meaning, but they still depend on tenant-local people, content, and permissions.

---

## Federation lanes

The current architecture is easiest to reason about when split into distinct lanes:

### Lane 1 — platform-to-platform network governance

This lane is about whether two platforms are connected and what they allow each other to do.

Current implementation examples:

- `PlatformConnection`
- `FederationAccessToken`
- `FederationScopeAuthorizer`
- `FederatedContentAuthorizer`

This lane belongs at the public/network boundary because it identifies platforms and their negotiated trust/configuration.

### Lane 2 — mirrored network content

This lane is about importing authorized content from another platform into a local platform's own search/feed/display context.

Current implementation examples:

- `FederatedPostMirrorService`
- `FederatedPageMirrorService`
- `FederatedEventMirrorService`
- provenance columns such as:
  - `platform_id`
  - `source_id`
  - `source_updated_at`
  - `last_synced_at`

This lane must **not** turn remote canonical ownership into shared local ownership. The local platform should keep:

- a local mirror/projection for local use
- explicit source attribution
- explicit sync state

Canonical ownership stays with the source platform.

### Lane 3 — person-linked private sharing

This lane is narrower and more sensitive than general platform federation.

Current implementation examples:

- `PersonLink`
- `PersonAccessGrant`
- `PersonLinkedSeed`

This lane is about explicit person-to-person sharing, not general network-feed visibility.

Private linked content:

- must stay recipient-scoped
- must stay encrypted at rest where implemented
- must not surface in general feed/search/community listings
- must not be treated as if a platform connection alone authorizes broad private-data exposure

---

## Current implementation evidence

### Platform-governance layer

`PlatformConnection` already behaves like a network-governance record:

- connects a `source_platform` and `target_platform`
- stores content-sharing policy and federation-auth policy
- controls content-type sharing toggles
- tracks sync state
- owns `FederationAccessToken` records

That is strong evidence that platform-to-platform trust belongs at the registry/network layer, not inside local content tables.

### Scope authorization layer

`FederationScopeAuthorizer` currently grants scopes by inspecting the active directed `PlatformConnection`.

That means:

- scopes are already treated as connection-based capabilities
- this should remain true under schema tenancy
- local tenant data should be accessed only after both:
  - network scope authorization passes
  - tenant-local authorization passes

### Mirrored content layer

`FederatedContentAuthorizer` already checks:

- active connection
- mirroring vs publish-back mode
- content type allowlist

That is a good network-layer guard, but it is not a substitute for tenant-local policy and provenance-aware moderation once content exists locally.

### Person-linked sharing lane

`PersonLink` and `PersonAccessGrant` already show the right conceptual split:

- link the two people through a platform connection
- enforce that source/target people belong to the respective source/target platforms
- keep grants recipient-scoped and explicit
- keep linked payloads out of general search/feed

That lane should remain explicit and narrow.

---

## Boundary rules

### Rule 1 — platform connections do not equal tenant access

An active `PlatformConnection` means:

- the two platforms have a network relationship
- some scopes or content-sharing options may be available

It does **not** mean:

- any local user from one platform can read arbitrary data in the other
- local tenant policies can be bypassed
- private community or safety data becomes shared by default

### Rule 2 — network authorization and tenant authorization are separate gates

Every federated action should pass two gates:

1. **network gate**
   - is there an active platform connection?
   - is the requested scope/content type allowed?
   - is the agreement/consent state sufficient?

2. **tenant-local gate**
   - inside the target platform schema, does local RBAC/privacy/community membership allow this action?

Passing the first gate must never silently imply the second.

### Rule 3 — mirrored content is local projection, not ownership transfer

Mirrored content should remain:

- local copy/projection
- source-attributed
- refreshable/revocable
- subject to local moderation/visibility rules
- stored inside the tenant schema of the internal platform that accepted the mirror

But:

- the source platform remains canonical owner
- publish-back requires separate explicit permission
- mirror presence must not erase source/target platform boundaries

### Rule 4 — external platforms stay registry-only inside CE

External peer platforms may have rich trust, routing, and connection metadata in `public`, but they do **not** get private working schemas inside CE.

If CE accepts remote data from an external peer through:

- federation mirroring
- OAuth/account linking
- seeded relationship sync
- another approved inbound data flow

that data must be stored as tenant-local data inside the schema of the internal platform that accepted it, with explicit provenance.

### Rule 5 — person-linked private sharing is not general federation

Person-linked private sharing should require:

- a durable person link
- explicit access grant(s)
- recipient-scoped visibility
- tenant-local policy checks on both ends where applicable

It must not broaden into:

- general network-feed eligibility
- general search eligibility
- implicit visibility for platform staff

### Rule 6 — safety and private spaces remain local by default

Unless a later ADR explicitly defines a federation lane for them, these remain local:

- direct/private messaging
- safety reports/cases/notes
- private communities and community-private participation
- locally protected/private content outside explicit sharing lanes

### Rule 7 — public registry records must not become shadow copies of private state

The public platform registry should store enough to:

- identify platforms
- route requests
- manage trust/connection policy
- expose manifest-level management metadata

It should not become a place to keep shadow copies of:

- local people
- local memberships
- local safety state
- local private content

---

## Placement guidance by model family

| Model / Family | Boundary | Why |
|----------------|----------|-----|
| `Platform` | `public` | Registry/gateway identity, routing, management metadata |
| `PlatformConnection` | public/network | Directed trust/connection contract between platforms |
| `FederationAccessToken` | public/network | Scoped token for an active platform connection |
| `FederationScopeAuthorizer` | public/network | Connection-based scope gate |
| `FederatedContentAuthorizer` | public/network + local policy follow-up | Connection/type gate only; not the final tenant-local authorization |
| `PersonLink` | hybrid: network edge referencing tenant-local people | Cross-platform relationship edge depends on tenant-local people |
| `PersonAccessGrant` | hybrid: network consent referencing tenant-local people | Explicit private-share consent should stay narrow and auditable |
| `PersonLinkedSeed` | target tenant schema, recipient-scoped | Private cached projection for one recipient, not general public/network state |
| mirrored content projection | target tenant schema | Local feed/search/display needs tenant-local projection with provenance |
| mirrored content provenance/sync contract | network + target tenant coordination | Needs both source identity and local projection state |

---

## Runtime implications

Federated execution under schema tenancy requires:

1. resolve the local target platform through the public registry
2. switch into the target platform schema
3. evaluate local tenant policy there
4. apply network/connection/consent gates in parallel as required

This means:

- federation endpoints cannot stop at `Current.platform`
- job-based sync cannot rely on shared-schema fallbacks
- local mirror ingest must carry both:
  - source-platform identity
  - target tenant-schema identity

Those runtime choices also sit inside a larger topology: infrastructure hosts, app instances, internal managed platforms, and external peers are distinct layers. See `infrastructure_app_platform_topology.md`.

---

## Current mismatches to resolve

### 1. Shared-schema runtime shortcuts still exist

Current code still leans on host-platform fallback and shared-schema access patterns. That makes it too easy for federation work to appear valid before tenant isolation is real.

### 2. Mirrored content currently uses platform-aware provenance, not full tenant-local mirror contract

The current provenance fields are useful groundwork, but they are not yet the complete schema-tenancy answer.

### 3. Person-linked lane still needs explicit boundary choices

`PersonLink`, `PersonAccessGrant`, and `PersonLinkedSeed` are conceptually right, but the final placement rules under tenant schemas need to remain explicit so private sharing does not drift into generalized network visibility.

### 4. RBAC cleanup remains mandatory

Federation actions still need distinct capability families. Generic `manage_platform` should not become the de facto authorization path for connection approval, OAuth trust, mirroring, or publish-back.

---

## Recommended implementation order

### Phase 1 — local isolation first

- establish tenant schema runtime
- remove host/shared fallbacks from tenant-local execution
- make local `User` / `Person` / `Community` ownership trustworthy

### Phase 2 — platform-governance lane

- stabilize `PlatformConnection`
- stabilize token/scope/connection policy
- clearly separate public registry metadata from tenant-local private data

### Phase 3 — mirrored-content lane

- make local mirror projections explicitly tenant-local
- preserve source attribution and sync state
- enforce tenant-local moderation and visibility after network authorization

### Phase 4 — person-linked private lane

- keep link + grant + linked-seed flow narrow
- ensure recipient-scoped storage and visibility
- explicitly prevent spillover into general feed/search/community surfaces

### Phase 5 — publish-back / advanced federation

- only after local isolation, mirror projections, and RBAC are trustworthy

---

## Success criteria

This boundary is satisfied when:

1. federation records identify and connect platforms without becoming homes for platform-private working data
2. mirrored content is locally projected without erasing source ownership
3. person-linked sharing remains explicit, narrow, and recipient-scoped
4. network authorization never replaces tenant-local authorization
5. federation features can expand without pressuring the app back toward shared private-state shortcuts

---

## Values and principles guidance

- **Care:** private sharing, safety, and community-private participation must not be widened by federation convenience
- **Accountability:** every cross-platform access path should show which network contract and which local authorization permitted it
- **Stewardship:** keep federation additive to local autonomy, not destructive of it
- **Solidarity:** connected platforms should cooperate through explicit agreements and trust edges, not through hidden centralization of private data
- **Resilience:** if federation is unavailable or revoked, local platform operation and local private boundaries must remain intact
