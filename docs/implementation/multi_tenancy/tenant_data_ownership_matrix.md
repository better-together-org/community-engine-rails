# Tenant Data Ownership Matrix

**Date:** March 11, 2026  
**Status:** Draft architecture baseline  
**Purpose:** Canonical ownership map for schema-per-platform multi-tenancy

---

## Summary

This document defines the target ownership class for major CE domains under the intended tenancy model:

- one PostgreSQL schema per hosted platform
- `public` schema reserved for fleet-level routing and provisioning metadata
- communities as the primary in-schema partition
- personal communities treated as first-class communities inside a tenant

This matrix is the source of truth for:

- `tenant_runtime_contract.md`
- `schema_per_tenant_implementation_plan.md`
- future migration and implementation work

If a domain cannot be confidently placed yet, it must be marked `needs-redesign` instead of inferred.

---

## Ownership Classes

| Class | Meaning |
|-------|---------|
| `public-global` | Lives in `public`; required for routing, provisioning, or fleet administration |
| `tenant-global` | Lives in a tenant schema; visible across that hosted platform |
| `community-scoped` | Lives in a tenant schema and must resolve to a community |
| `personal-community-scoped` | Lives in a tenant schema and is anchored to a person’s personal community |
| `cross-tenant-admin` | Fleet-level operational or reporting data spanning tenants |
| `needs-redesign` | Current implementation is mixed or unclear; target placement must be resolved before implementation |

---

## Canonical Matrix

| Domain / Model Family | Current Shape | Target Ownership | Notes |
|-----------------------|---------------|------------------|-------|
| `Platform` | Shared-schema platform table | `public-global` | Global source for domain routing, schema name, provisioning status, backup metadata |
| Platform provisioning state | Not implemented | `public-global` | Includes schema lifecycle, provisioning errors, timestamps, backup health |
| Domain / subdomain routing metadata | Not implemented | `public-global` | Must resolve request host to one tenant schema |
| Fleet support metadata | Not implemented | `cross-tenant-admin` | Support tooling, operational notes, schema inventory, incident metadata |
| `Community` | Shared-schema main organizing boundary | `community-scoped` | First-class in-tenant partition for host, personal, and additional communities |
| Host community designation | Host flag in shared schema | `community-scoped` | One per tenant; platform default community |
| Personal community | Emerges via `PrimaryCommunity` concern | `personal-community-scoped` | Must be formalized as a first-class community concept |
| `Person` profile | Mixed; has `community_id` plus memberships | `tenant-global` | Tenant-local person record; may reference a personal community |
| User authentication / identity | Shared app auth today | `needs-redesign` | Must decide global identity vs tenant-local identity/profile split |
| `PersonCommunityMembership` | Community membership | `community-scoped` | Remains community-based inside tenant |
| `PersonPlatformMembership` | Platform membership | `tenant-global` | Tenant-wide organizer/admin/member relationships |
| Roles | Shared definitions today | `tenant-global` | Seeded or copied into each tenant schema |
| Resource permissions | Shared definitions today | `tenant-global` | Must align to tenant-local role assignment |
| Pages | Community-oriented | `community-scoped` | Defaulting should use explicit current community rules, not host fallback magic |
| Posts | Mixed/shared today | `community-scoped` | Target is community ownership inside tenant |
| Content blocks | Mixed/shared today | `needs-redesign` | Block ownership must resolve to platform-global vs community-owned block families |
| Platform blocks / tenant branding blocks | Platform-scoped today | `tenant-global` | Tenant-wide theming, CSS, shared platform presentation |
| Navigation areas / items | Mixed/shared today | `needs-redesign` | Must separate tenant-global nav from community-local nav |
| Calendars | Community-scoped | `community-scoped` | Personal calendars remain community-anchored through personal community |
| Events | Community-oriented | `community-scoped` | Event host and visibility remain community-driven |
| Event attendance / invitations | Mixed around events and people | `community-scoped` | Belongs with the event’s community, with tenant-local people |
| Geography / places / infrastructure | Community-scoped | `community-scoped` | Strong fit for in-schema community boundary |
| Conversations / messages | Mixed/shared today | `needs-redesign` | Must define whether direct messaging is tenant-global or community-anchored |
| Notifications | Shared/infrastructure today | `needs-redesign` | Delivery artifacts may be tenant-local; fleet ops may need cross-tenant visibility |
| Person blocks / reports / moderation records | Mixed social safety records | `tenant-global` | Safety operations are tenant-wide, though some records reference community context |
| Webhook endpoints | Community-scoped today | `community-scoped` | Community-owned endpoints stay community-owned unless an explicit tenant-global class is introduced |
| OAuth applications / external integrations | Mixed/shared today | `needs-redesign` | Decide tenant-global vs fleet-global integration surfaces |
| Search indexes / search metadata | Shared today | `needs-redesign` | Must define tenant-local indexing and cross-tenant admin reporting path |
| Metrics / analytics | Shared today | `needs-redesign` | Split tenant analytics from fleet observability explicitly |
| Background job context | No tenant support today | `tenant-global` | Execution context belongs to one tenant, optionally one community |
| Mailer rendering context | No tenant support today | `tenant-global` | URLs, branding, and lookups must run in one tenant context |

---

## Defaults Chosen For Planning

The following defaults are chosen for the planning package and should be treated as provisional architecture decisions unless superseded by a dedicated ADR:

1. `Platform` remains in `public`.
2. `Community` remains the primary data partition inside each tenant.
3. `Person` becomes tenant-local, not fleet-global, unless identity requirements prove otherwise.
4. Personal communities are explicit tenant-local communities, not incidental side effects of callbacks.
5. Roles and permissions are tenant-local definitions, even if seeded from a common template.

---

## Domains Marked `needs-redesign`

These domains require explicit ownership and migration design before implementation:

- user identity and authentication boundaries
- content block ownership model
- navigation ownership model
- conversations and messages
- notifications
- OAuth and external integrations
- search and analytics architecture

These should not be left implicit in the implementation plan.

---

## Review Checklist

- Every major domain has exactly one target ownership class.
- No target row depends on schema-per-tenant behavior that is undefined in the runtime contract.
- Every `needs-redesign` row is carried into the implementation plan as a prerequisite decision, not silently assumed.
