# Platform Schema Migration Map

**Date:** April 5, 2026  
**Status:** Planning baseline  
**Purpose:** Map CE model families from the current shared-schema implementation to the intended public-registry + per-platform-schema architecture

---

## Why this document exists

The architecture docs now distinguish clearly between:

- the **public platform registry/gateway layer**
- each platform's **tenant schema**
- **community-scoped** data inside each tenant schema
- **network-shared** federation records

What was still missing was a practical migration map: which model families move, which stay in `public`, which need redesign instead of a simple move, and which blockers must be cleared before code migration begins.

This document is that map.

It complements:

- `platform_registry_and_schema_boundary.md`
- `federation_registry_and_tenant_boundary.md`
- `tenant_data_ownership_matrix.md`
- `tenant_runtime_contract.md`
- `schema_per_tenant_implementation_plan.md`
- `../../assessments/multi_tenancy_gap_assessment_2026-03-11.md`

---

## Migration classes

| Class | Meaning |
|-------|---------|
| `stay-public` | Remains in `public` because it is registry/gateway/cross-tenant data |
| `move-tenant-global` | Moves into each platform schema and is visible platform-wide there |
| `move-community-scoped` | Moves into each platform schema and remains row-scoped by community |
| `move-personal-community` | Moves into each platform schema and remains anchored to a person's personal community |
| `network-redesign` | Needs explicit federation/network modeling instead of a simple move |
| `ops-redesign` | Needs tenant-aware operational lifecycle work before or during the move |

---

## Canonical migration map

| Domain / Model Family | Current Shape | Target Boundary | Migration Class | Migration Approach | Main Blockers / Notes |
|-----------------------|---------------|-----------------|-----------------|-------------------|-----------------------|
| `Platform` registry records | Shared-schema table with mixed responsibilities | `public` | `stay-public` | Keep only direct platform-management, manifest, routing, schema identity, and connected-platform metadata in `public` | Need explicit column-level contract for what stays public |
| Platform translated attrs used for management/manifest/routing | Mixed into platform records today | `public` | `stay-public` | Keep only translated attrs required for management, manifest publication, and routing | Need explicit translation-field allowlist |
| `PlatformDomain` / routing manifest | Shared-schema hostname table | `public` | `stay-public` | Expand into full routing manifest for localized primary domains and permission-gated vanity/campaign domains | Current model only has `hostname`, `primary`, `active` |
| Platform provisioning lifecycle | Not implemented | `public` + ops layer | `ops-redesign` | Add schema identity, provisioning state, migration fan-out status, health, and rollback markers | No tenant lifecycle yet |
| `User` / auth state | Shared-schema local accounts | tenant schema | `move-tenant-global` | Move per-platform accounts into each platform schema; keep only cross-platform linkage metadata outside | Requires real schema switching, auth/session strategy, and tenant-aware Devise/Doorkeeper contract |
| `Person` / `Identification` | Shared-schema identity with community/platform links | tenant schema | `move-tenant-global` | Move local person/profile state into tenant schemas; preserve per-platform autonomy | Current model mixes community and platform assumptions; personal-community implications must be preserved |
| `PersonPlatformMembership` | Shared-schema platform membership | tenant schema | `move-tenant-global` | Recreate as tenant-local platform membership inside each platform schema | Depends on platform-local accounts/people |
| `Community` | Shared-schema organizing boundary | tenant schema | `move-community-scoped` | Move communities into each platform schema; keep row-level scoping there | Need host-community and primary-community creation contract to become tenant-aware |
| `PersonCommunityMembership` | Shared-schema community memberships | tenant schema | `move-community-scoped` | Keep same conceptual model inside platform schema | Depends on tenant-local people and communities |
| Personal communities | Emergent via concerns | tenant schema | `move-personal-community` | Preserve per-person personal communities inside each tenant schema | Must avoid host-community silent fallback |
| Roles / permissions | Effectively shared/global definitions today | tenant schema | `move-tenant-global` | Seed role catalog and resource permissions per tenant schema | Requires RBAC cleanup and federation permission-family redesign |
| Invitations / onboarding | Mixed platform/community behavior in shared schema | tenant schema | `move-tenant-global` + `move-community-scoped` | Split platform-local admission state from community-local participation state | Must preserve invitation-only, onboarding, and agreement gates under tenant-local auth |
| Pages / posts / events | Mixed community/platform behavior; some `platform_id` backfills | tenant schema | `move-community-scoped` | Stop treating `platform_id` backfill as final tenancy; make canonical local records tenant-local, community-scoped | Current `platform_id` usage is groundwork, not final isolation |
| Blocks / reusable templates / branding | Mixed/shared today | tenant schema | `move-community-scoped` and `move-tenant-global` | Split community-owned blocks from tenant-wide reusable assets | Need explicit ownership rules per block family |
| Navigation areas/items | Mixed/shared today | tenant schema | `move-tenant-global` and `move-community-scoped` | Separate tenant-wide organizer/account nav from community-local nav | Current ownership is not cleanly encoded |
| Calendars / geography / places / infrastructure | Shared-schema community-owned records | tenant schema | `move-community-scoped` | Preserve existing community-centric design inside tenant schema | Mostly straightforward once community boundary exists |
| Conversations / messages | Mixed/shared today | tenant schema | `move-tenant-global` | Keep messaging local to one platform schema; no table-sharing across platforms | Needs tenant-aware messaging context and explicit non-federation rule for private spaces |
| Notifications | Shared/infrastructure today | tenant schema | `move-tenant-global` | Keep product notifications local to a platform schema | Existing notification plumbing may reference shared records with nullable `platform_id` |
| Reports / safety cases / safety notes / moderation | Mixed safety records | tenant schema | `move-tenant-global` | Keep safety handling platform-local unless a later ADR creates a separate federation safety lane | Must align with least-privilege privacy model and explicit disclosure rules |
| Webhook endpoints | Community-scoped today | tenant schema | `move-community-scoped` | Keep endpoints local to community/platform schema | Need tenant-aware delivery context and secret storage assumptions |
| OAuth applications / local auth config | Mixed/shared today | tenant schema | `move-tenant-global` | Each platform should have local OAuth provider/client config in its own schema | Must distinguish local auth config from cross-platform trust metadata |
| Platform connections / agreements / shared auth/sync consent | Shared registry/federation layer | `public` + network layer | `network-redesign` | Keep cross-platform connection/trust records outside tenant-local content tables, but reference tenant-local actors/data explicitly | Need stable source/target platform identity without collapsing tenant-local ownership |
| Linked accounts / person links / access grants | Partially approximated today | network layer + tenant schemas | `network-redesign` | Use explicit cross-platform linkage records plus tenant-local account/person records | Needs clear placement for encrypted private-share artifacts and local projections |
| Mirrored content / sync state | Partial provenance on local content | network layer + tenant schemas | `network-redesign` | Keep canonical remote identity/network state explicit while storing local mirror projections in tenant-local search/feed context | Needs explicit source attribution and refresh contract |
| Search indexes / feed aggregation | Shared today | tenant schema + network layer | `network-redesign` | Build local per-platform search/feed state that can include authorized mirrored content | Needs tenant-aware indexing and mirror eligibility logic |
| Metrics / analytics | Shared today | tenant schema by default | `move-tenant-global` | Default platform analytics to tenant-local storage; treat fleet reporting as separate cross-tenant export/reporting lane | Need explicit exceptions for cross-tenant observability |
| Background jobs | No tenant support today | ops/runtime layer + tenant schemas | `ops-redesign` | Carry platform/schema identity in every job payload and switch schema before work | No tenant-aware job contract yet |
| Mailers | No tenant support today | ops/runtime layer + tenant schemas | `ops-redesign` | Resolve platform/schema context before rendering and delivery | No tenant-aware mailer context yet |
| Fleet observability / backup / restore / migration fan-out | Shared ops concern | cross-tenant ops | `stay-public` + `ops-redesign` | Keep fleet oversight outside tenant schemas while making per-tenant operations explicit and auditable | Needs operator runbook and lifecycle tooling |

---

## Recommended migration waves

### Wave 0 — truth, contracts, and registry cleanup

- finalize the public-vs-tenant boundary
- define the public `Platform` column/translation allowlist
- define routing-manifest semantics:
  - primary domains
  - localized primary-domain variants
  - vanity/campaign domains
- correct release notes and upgrade docs

### Wave 1 — tenant runtime foundation

- add `tenant_schema` identity to local platforms
- implement host -> public platform record -> tenant schema resolution
- switch schemas before controller logic
- propagate tenant context to jobs, mailers, and URL helpers

### Wave 2 — identity and governance core

- tenant-local `User`
- tenant-local `Person`
- tenant-local platform/community memberships
- tenant-local communities and personal communities
- tenant-local role and permission seeding

These are the minimum foundation for trustworthy private-data isolation.

### Wave 3 — local product data

- invitations/onboarding
- content, blocks, navigation
- conversations/messages
- notifications
- reports/safety records
- webhooks
- metrics and search

### Wave 4 — federation reconciliation

- platform connections
- agreements and consent
- linked accounts
- mirrored content
- search/feed inclusion of authorized mirrors

This wave must be done **after** local tenant ownership is trustworthy.

### Wave 5 — fleet operations

- schema provisioning
- migration fan-out
- backup/restore per tenant
- tenant inventory and health
- routing/public-edge operational runbook

---

## Highest-risk blockers

### 1. Auth/session assumptions

If `User` becomes truly tenant-local, sign-in, password reset, OAuth provider/client behavior, and invitation/onboarding flows all need a tenant-aware contract.

### 2. Host fallback shortcuts

Current host-platform/host-community fallbacks are convenient in a shared schema, but they become dangerous once tenant context is mandatory.

### 3. Shared infrastructure tables with mixed ownership

Notifications, metrics, search, and some block/navigation surfaces currently mix platform/global assumptions. These must be classified before migration.

### 4. Federation pressure

Federation features can easily tempt the design back toward shared private-state shortcuts. Cross-platform features must be explicit network contracts, not exceptions that erode local schema ownership.

### 5. Routing manifest incompleteness

The intended locale-aware and vanity/campaign-aware domain routing contract is not yet encoded in the current `PlatformDomain` model.

---

## Success criteria for the migration map

This map is successful when it lets implementation teams answer, for every affected model family:

1. Does it stay in `public`, move into the tenant schema, or need a federation/ops redesign?
2. If it moves, is it tenant-global, community-scoped, or personal-community-scoped?
3. What prerequisite runtime or RBAC work must land first?
4. What current shared-schema shortcuts must be removed to make the move trustworthy?

---

## Values and principles guidance

- **Care:** migration order must prioritize the data families that matter most for privacy and safety
- **Accountability:** every exception to tenant-local ownership should be documented explicitly, not left as an implicit legacy shortcut
- **Stewardship:** prefer migration waves with clear rollback boundaries over one-shot tenant rewrites
- **Solidarity:** preserve meaningful autonomy for each platform instead of drifting back toward host-global private data
- **Resilience:** tenant runtime, routing, and operations must fail closed rather than silently routing data to the wrong platform or fallback host context
