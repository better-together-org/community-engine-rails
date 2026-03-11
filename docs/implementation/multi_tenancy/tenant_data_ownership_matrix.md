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
| `User` credentials | Shared app auth today | `public-global` | One credential identity can authenticate across hosted platforms |
| `Identification` link layer | Shared auth-to-person link today | `public-global` | Maps public-global user credentials to tenant-local person profiles |
| `PersonCommunityMembership` | Community membership | `community-scoped` | Remains community-based inside tenant |
| `PersonPlatformMembership` | Platform membership | `tenant-global` | Tenant-wide organizer/admin/member relationships |
| Roles | Shared definitions today | `tenant-global` | Seeded or copied into each tenant schema |
| Resource permissions | Shared definitions today | `tenant-global` | Must align to tenant-local role assignment |
| Pages | Community-oriented | `community-scoped` | Defaulting should use explicit current community rules, not host fallback magic |
| Posts | Mixed/shared today | `community-scoped` | Target is community ownership inside tenant |
| Page-owned content blocks | Mixed/shared today | `community-scoped` | Blocks attached to pages or community-owned records inherit community ownership |
| Reusable templates and branding blocks | Mixed/shared today | `tenant-global` | Shared presentation assets, CSS blocks, reusable templates |
| Platform blocks / tenant branding blocks | Platform-scoped today | `tenant-global` | Tenant-wide theming, CSS, shared platform presentation |
| Tenant-global navigation | Mixed/shared today | `tenant-global` | Global headers, footer nav, account and organizer navigation inside one platform |
| Community navigation | Mixed/shared today | `community-scoped` | Community hub/sidebar/navigation trees owned by one community |
| Calendars | Community-scoped | `community-scoped` | Personal calendars remain community-anchored through personal community |
| Events | Community-oriented | `community-scoped` | Event host and visibility remain community-driven |
| Event attendance / invitations | Mixed around events and people | `community-scoped` | Belongs with the event’s community, with tenant-local people |
| Geography / places / infrastructure | Community-scoped | `community-scoped` | Strong fit for in-schema community boundary |
| Conversations / messages | Mixed/shared today | `tenant-global` | Direct messaging spans communities within one platform; optional community context may be attached |
| Notifications | Shared/infrastructure today | `tenant-global` | Product notifications are tenant-local; fleet delivery telemetry is separate |
| Person blocks / reports / moderation records | Mixed social safety records | `tenant-global` | Safety operations are tenant-wide, though some records reference community context |
| Webhook endpoints | Community-scoped today | `community-scoped` | Community-owned endpoints stay community-owned unless an explicit tenant-global class is introduced |
| Tenant integrations / OAuth applications | Mixed/shared today | `tenant-global` | Integrations and OAuth apps belong to one hosted platform unless explicitly fleet-admin |
| Search indexes / search metadata | Shared today | `tenant-global` | Product search indexes are tenant-local; fleet search requires separate admin indexing |
| Product metrics / analytics | Shared today | `tenant-global` | Product analytics belong to one tenant; fleet observability remains separate |
| Fleet observability / delivery telemetry | Shared ops concern today | `cross-tenant-admin` | Monitoring, indexing, backup oversight, and delivery telemetry span tenants |
| Background job context | No tenant support today | `tenant-global` | Execution context belongs to one tenant, optionally one community |
| Mailer rendering context | No tenant support today | `tenant-global` | URLs, branding, and lookups must run in one tenant context |

---

## Defaults Chosen For Planning

The following defaults are chosen for the planning package and should be treated as provisional architecture decisions unless superseded by a dedicated ADR:

1. `Platform` remains in `public`.
2. `Community` remains the primary data partition inside each tenant.
3. `Person` is tenant-local, while `User` credentials and `Identification` remain public-global.
4. Personal communities are explicit tenant-local communities, not incidental side effects of callbacks.
5. Roles and permissions are tenant-local definitions, even if seeded from a common template.
6. Product notifications, search, and analytics are tenant-local; fleet observability is a separate cross-tenant-admin concern.

---

## Resolution Notes

This draft resolution pass makes the following architectural choices:

- identity is split between public-global credentials and tenant-local person profiles
- messaging is tenant-global so direct messaging can cross communities within a platform
- navigation and content blocks are split into tenant-global and community-scoped families
- product search, notifications, and analytics are tenant-local
- fleet monitoring and observability are separate cross-tenant-admin systems

Any implementation that diverges from these decisions should introduce an ADR first.

---

## Review Checklist

- Every major domain has exactly one target ownership class.
- No target row depends on schema-per-tenant behavior that is undefined in the runtime contract.
- Any future exception to these ownership defaults is captured explicitly as an ADR.
