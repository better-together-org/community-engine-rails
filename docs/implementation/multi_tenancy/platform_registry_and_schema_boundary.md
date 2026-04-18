# Platform Registry And Schema Boundary

**Date:** April 5, 2026  
**Status:** Architecture reconciliation baseline  
**Purpose:** Canonical boundary for what remains in `public` versus what belongs in each internally hosted platform schema

---

## Why this document exists

Community Engine's intended architecture is:

- platform multi-tenancy at the **schema** level
- community multi-tenancy at the **row** level inside each platform schema
- explicit federation between local hosted platforms and external peer platforms

The topology around that platform model also needs to stay explicit:

- infrastructure host/steward is not the same thing as an app instance node
- app instance node is not the same thing as a managed platform
- host-platform defaults must not be treated as proof that the routed platform is an internal schema-bearing tenant

The current codebase contains real platform-aware groundwork, but it does **not** yet implement schema switching or full platform-private data isolation. This document clarifies the intended boundary so release notes, upgrade docs, and future implementation work do not overclaim the shipped state.

It complements:

- `infrastructure_app_platform_topology.md`
- `tenant_runtime_contract.md`
- `tenant_data_ownership_matrix.md`
- `platform_schema_migration_map.md`
- `federation_registry_and_tenant_boundary.md`
- `schema_per_tenant_implementation_plan.md`
- `../../assessments/multi_tenancy_gap_assessment_2026-03-11.md`

---

## Executive summary

### Target model

- `public` holds the **platform registry/gateway layer**
- each internally hosted platform owns its **private/local working data** inside its own tenant schema
- communities remain the primary organizing and permission boundary inside that tenant schema
- federation records remain explicit cross-platform relationships and must not collapse tenant isolation

### Important public-schema exception

The `better_together_platforms` table remains in `public`, including the direct platform attributes required for:

- platform management
- platform manifest participation
- routing
- localized domain selection
- connected-platform governance

This does **not** mean platform-private records should remain in `public`.

It also does **not** mean every platform record represents an internal tenant schema. Internal managed platforms and external peer platforms both live in the public registry, but only internal managed platforms own tenant schemas in CE.

### Current implementation reality

Today CE still runs as a shared-schema app with:

- `Current.platform` host resolution
- `PlatformDomain` hostname lookup
- selected `platform_id`-scoped records
- community-scoped records in the shared schema
- host-platform and host-community fallbacks in several code paths

The current runtime is therefore **platform-aware groundwork**, not completed schema-isolated hosted-platform tenancy.

---

## Public schema contract

`public` is the shared registry and gateway layer. It should hold only what is necessary to route, identify, govern, and connect platforms.

### Public data that belongs in `public`

1. **Platform registry records**
   - one record per internally hosted platform
   - one record per known external peer platform
   - provisioning state, external/local flags, privacy/network defaults, and lifecycle metadata
   - tenant schema identity only for internally hosted platforms

2. **Direct platform-management metadata**
   - direct platform attributes used to manage the platform as a registered platform
   - translated/localized platform attributes only when those attributes are required for:
     - platform management
     - manifest publication
     - routing/domain presentation

3. **Routing manifest**
   - primary platform-domain metadata
   - localized primary-domain metadata across supported/configured locales
   - permitted alternate domains
   - permitted campaign/vanity domains when the platform has explicit authorization to use them

4. **Cross-platform registry and trust data**
   - external peer platform metadata
   - platform connections
   - trust/bootstrap state
   - agreement/bootstrap metadata that spans platforms

5. **Cross-tenant operational metadata**
   - fleet inventory
   - tenant schema lifecycle records
   - migration fan-out status
   - cross-tenant observability and diagnostics

### Public data that should *not* stay in `public`

Unless a later ADR explicitly carves out an exception, `public` should **not** remain the home of:

- local `User` accounts
- local `Person` profiles
- local communities and memberships
- platform-private invitations and onboarding state
- direct messaging/conversations
- reports, safety cases, and safety notes
- local pages, posts, events, blocks, and navigation
- platform-private analytics, notifications, and search state

Those belong to the tenant schema of the internally hosted platform that owns them.

---

## Tenant schema contract

Each tenant schema is the home of one **internally hosted** platform's local/private operating data.

### Data families that belong in each internally hosted platform schema

- local `User` accounts and authentication state
- local `Person` profiles and identifications
- platform memberships and community memberships
- host community, personal communities, and additional communities
- invitations, onboarding, and agreement-participation state that is local to that platform
- conversations, messages, and notifications
- safety reports, safety cases, safety notes, and moderation artifacts
- pages, posts, events, blocks, navigation, search indexes, and other platform content
- local analytics/metrics unless a deliberate cross-tenant exception is approved

External peer platforms do **not** receive their own local tenant schemas in this app. Their metadata stays in `public`, and any remote data that CE chooses to ingest is stored as tenant-local data inside the schema of the internally hosted platform that accepted or mirrored it.

### Community scope inside a tenant schema

Inside a platform schema:

- communities remain the row-level organizing boundary
- community-private visibility remains membership-gated
- personal communities remain tenant-local
- host community convenience must not become a silent fallback for unrelated records

---

## Routing and domain contract

Routing is resolved from the public registry layer and then activates the tenant schema **only for internally hosted platforms**.

### Target routing flow

1. Receive request host.
2. Resolve the host through the public platform registry/domain manifest.
3. Match a permitted domain for the platform:
   - primary domain
   - localized primary-domain variant
   - authorized campaign/vanity domain
4. Load the platform registry record from `public`.
5. If the platform is internally hosted, resolve its tenant schema.
6. Switch into that tenant schema before controller logic.
7. Fail closed if the host is unknown, inactive, unauthorized, mismatched, or points at an external-only platform record for a local-app route.

### Current code limitation

Current `PlatformDomain` behavior only models:

- `hostname`
- `primary`
- `active`

It does **not yet** encode:

- locale
- domain class/type
- campaign/vanity authorization
- primary-domain selection per locale

That capability remains part of the intended routing contract, not proven released behavior.

---

## Federation boundary

Federation must not weaken local platform autonomy.

### Required boundary

- the public platform registry identifies and connects platforms
- tenant schemas own local private data for internally hosted platforms only
- external peers remain registry records, not local tenant schemas
- remote data ingested from external peers becomes tenant-local data inside the schema of the internal platform that accepted it, with explicit provenance
- mirrored content, linked accounts, OAuth trust, and agreements remain explicit cross-platform relationships
- direct/private tenant-local spaces stay local unless a separate approved design expands them

### Design consequence

Federation should connect platforms **through** the public registry/gateway layer, not by moving platform-private data back into shared tables.

## Topology note

For BTS-operated infrastructure and client-hosted app instances, the architecture needs three distinct accountability layers:

1. **infrastructure hosts / stewards**
   - servers such as `bts-0`, `bts-4`, `bts-5`
   - hardware, secrets, network, observability, and uptime stewardship
2. **app instance nodes**
   - one CE deployment plus its local database/runtime boundary
   - edge routing, TLS, bot protection, operational support, and local app health
3. **managed platforms**
   - public registry records representing either:
     - internal schema-bearing platforms managed by that app instance
     - external peer platforms used for federation/trust only

That distinction matters because a host platform in governance or operational language may not be the same thing as an internal tenant platform in schema-tenancy language.

See `infrastructure_app_platform_topology.md` for the fuller four-layer contract covering infrastructure hosts, app instances, managed platforms, and communities.

---

## Current mismatch to address

The current code/documentation mismatch is now clear:

1. **Planning docs** describe schema-per-platform tenancy.
2. **Release notes** currently overstate the shipped result.
3. **Runtime code** currently resolves `Current.platform` but does not switch schemas.
4. **Data ownership** still mixes:
   - shared-schema platform records
   - shared-schema community-owned records
   - selected `platform_id` slices
   - host fallbacks

This is why `0.11.0` should be described as **platform-aware groundwork plus federation primitives**, not completed schema isolation.

---

## Implementation phases

### Phase 0 — truth alignment

- correct release notes and upgrade docs
- make the public-vs-tenant boundary explicit
- stop claiming universal per-model tenant scoping

### Phase 1 — public registry hardening

- define exactly which `Platform` attributes stay in `public`
- add explicit routing/manifest semantics for localized primary domains and permitted vanity/campaign domains
- document or implement the permission model for campaign/vanity routing

### Phase 2 — tenant runtime

- add tenant schema identity to local platforms
- resolve host -> platform registry record -> tenant schema
- set `Current.platform` and `Current.tenant_schema`
- switch schemas before normal controller execution
- make jobs, mailers, and background processes tenant-aware

### Phase 3 — data-family migration

- move platform-private records into tenant schemas
- preserve only direct platform registry/gateway records in `public`
- remove host-platform/host-community fallback assumptions where tenant context should be required

### Phase 4 — federation reconciliation

- ensure platform connections, agreements, mirrored content, and linked accounts remain explicit cross-platform contracts
- prevent federation features from reintroducing shared private-data shortcuts

### Phase 5 — operator lifecycle

- document provisioning, routing, DNS, host allowlists, migration fan-out, backup, restore, and rollback for platform schemas

Operator baseline:

- `../production/platform_provisioning_and_routing_runbook.md`

### Phase 6 — validation

- prove host resolution, schema switching, unknown-host fail-closed behavior, tenant isolation, and correct release/operator documentation

---

## Values and principles guidance

- **Care:** do not overstate privacy or isolation guarantees that the code does not yet provide
- **Accountability:** keep intended and implemented boundaries visible and auditable
- **Stewardship:** move in reversible phases with explicit rollback points
- **Solidarity:** preserve platform autonomy and avoid collapsing private community data into a host-global control plane
- **Resilience:** remove silent shared-schema fallbacks that weaken isolation and make failures harder to reason about
