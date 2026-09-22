# Federated Platform Ownership Matrix

**Date:** March 11, 2026  
**Status:** Draft architecture baseline  
**Purpose:** Canonical ownership map for schema-per-platform tenancy plus federated CE platform networking

---

## Summary

This document defines target ownership for major CE domains under the new architecture:

- each hosted CE platform on this server keeps its own tenant schema
- remote CE and non-CE platforms can exist as external platform records
- each platform keeps its own local `User`, `Person`, memberships, onboarding, and private spaces
- cross-platform sign-in and API access use OAuth between platforms
- linked platform accounts form one layer of the social and platform network
- platform, community, and person connection requests use a shared request primitive
- shared content is opt-in, agreement-backed, mirrored locally, and may support bi-directional sync where both platforms allow it

This matrix is the source of truth for:

- `tenant_runtime_contract.md`
- `schema_per_tenant_implementation_plan.md`
- `federated_rbac_reassessment_and_coverage_plan.md`
- future federation, sync, and tenancy implementation work

---

## Ownership Classes

| Class | Meaning |
|-------|---------|
| `public-global` | Lives in `public`; shared across the host CE instance for routing, peer platform metadata, or fleet administration |
| `tenant-global` | Lives in one local tenant schema and is visible across that platform |
| `community-scoped` | Lives in one local tenant schema and resolves to a community |
| `personal-community-scoped` | Lives in one local tenant schema and is anchored to a person’s personal community |
| `network-shared` | Represents a cross-platform linkage, mirror, agreement, or sync contract spanning more than one platform |
| `cross-tenant-admin` | Fleet-level operational or reporting data spanning many locally hosted tenants |

---

## Canonical Matrix

| Domain / Model Family | Current Shape | Target Ownership | Notes |
|-----------------------|---------------|------------------|-------|
| Local hosted `Platform` | Shared-schema platform table | `public-global` | Source of routing, schema name, provisioning state, privacy defaults, peer metadata |
| External peer `Platform` | `external` flag already exists | `public-global` | Represents remote CE or non-CE platforms known to the host app |
| Platform provisioning state | Not implemented | `public-global` | Tracks schema lifecycle for locally hosted platforms only |
| Platform network trust / visibility settings | Not implemented | `public-global` | Controls default privacy, sharing opt-in, peer/member platform relationships |
| Host CE platform default connection request | Not implemented | `public-global` | Pre-seeded outbound request from the BTS/CE host platform to new private platforms |
| Fleet support metadata | Not implemented | `cross-tenant-admin` | Local operations, tenant inventory, schema health, sync diagnostics |
| Local `User` credentials | Already local today | `tenant-global` | Each platform owns its own accounts; no host-wide global credential table |
| Local `Person` profile | Already local today | `tenant-global` | Platform-local identity profile used for memberships, content, and community graph |
| `Identification` inside a platform | Already local today | `tenant-global` | Links local account and local person within one platform |
| Network account linkage | Partially approximated by integrations today | `network-shared` | Links one local platform account to another platform account and may drive sign-in, sync, and graph edges |
| `Community` | Shared-schema main organizing boundary | `community-scoped` | First-class in-tenant partition for host, personal, and additional communities |
| Host community designation | Host flag in shared schema | `community-scoped` | One per platform; default local community |
| Personal community | Emerges via `PrimaryCommunity` concern | `personal-community-scoped` | Explicit community used for person-owned mutual aid and direct connection flows |
| `PersonCommunityMembership` | Community membership | `community-scoped` | Remains the main in-platform community participation model |
| `PersonPlatformMembership` | Platform membership | `tenant-global` | Platform-wide organizer/member/admin roles remain local |
| Roles | Shared definitions today | `tenant-global` | Seeded per local platform schema; role catalog must be streamlined before federation work |
| Resource permissions | Shared definitions today | `tenant-global` | Applied inside one platform; new federation and mirrored-content permission families are required |
| Connection request subtype | `Joatu::Request` already has polymorphic target | `network-shared` | Shared request primitive for person/community/platform connection workflows |
| Accepted connection edges | Not implemented | `network-shared` | Canonical relationship layer between people, communities, and platforms |
| Agreements for auth/sharing/sync consent | Existing agreement system | `network-shared` | Records consent and terms for linked identities, mirrored content, and publication rights |
| Pages | Community-oriented | `community-scoped` | Local canonical records inside one platform |
| Posts | Mixed/shared today | `community-scoped` | Local canonical records inside one platform |
| Page-owned content blocks | Mixed/shared today | `community-scoped` | Blocks attached to local community-owned records inherit community ownership |
| Reusable templates and branding blocks | Mixed/shared today | `tenant-global` | Platform-wide assets inside one local platform |
| Tenant-global navigation | Mixed/shared today | `tenant-global` | Account, organizer, and tenant-level nav inside one platform |
| Community navigation | Mixed/shared today | `community-scoped` | Community-local navigation structures |
| Calendars | Community-scoped | `community-scoped` | Personal calendars remain tied to personal communities |
| Events | Community-oriented | `community-scoped` | Local canonical records tied to communities |
| Event attendance / invitations | Mixed around events and people | `community-scoped` | Local participation records |
| Geography / places / infrastructure | Community-scoped | `community-scoped` | Remains local and community-owned |
| Conversations / messages | Mixed/shared today | `tenant-global` | Direct messaging stays local to one platform; cross-platform sharing happens through the network layer, not message table reuse |
| Notifications | Shared/infrastructure today | `tenant-global` | Product notifications are local to one platform |
| Person blocks / reports / moderation records | Mixed safety records | `tenant-global` | Moderation remains platform-local unless a separate federation policy is added later |
| Webhook endpoints | Community-scoped today | `community-scoped` | Community-owned local endpoints |
| OAuth applications / peer platform auth config | Mixed/shared today | `tenant-global` | Each CE platform can act as OAuth provider and client for other CE platforms |
| Person platform integrations | OAuth with external services today | `network-shared` | Expands to include CE peer account links in addition to external service integrations |
| Mirrored network content records | Not implemented | `network-shared` | Local mirror/cache of authorized remote content with source metadata and sync state |
| Mirror refresh / publish jobs | Not implemented | `network-shared` | Sync orchestration across platforms, scoped by agreements and sharing policy |
| Product search indexes / search metadata | Shared today | `tenant-global` | Local platform search indexes local plus authorized mirrored content |
| Product metrics / analytics | Shared today | `tenant-global` | Local platform analytics for native and mirrored content consumption |
| Network feed aggregation state | Not implemented | `network-shared` | Tracks what connected platforms and linked accounts contribute to the feed |
| Fleet observability / delivery telemetry | Shared ops concern today | `cross-tenant-admin` | Monitoring, indexing, sync diagnostics, backup oversight, and local operations telemetry |
| Background job context | No tenant support today | `tenant-global` | Local job execution belongs to one platform, with optional network sync context |
| Mailer rendering context | No tenant support today | `tenant-global` | Mailers render in one platform context; network invitations and connection flows may reference remote peers |

---

## Defaults Chosen For Planning

1. Each platform keeps its own local accounts and people.
2. CE-to-CE OAuth is used for federated sign-in and authorized API access between platforms.
3. Linked platform accounts serve both as identity links and as network relationship edges.
4. Platforms are private by default and must opt in to sharing content with networked platforms.
5. New private platforms receive a pre-seeded connection request from the BTS/CE host platform.
6. Mirrored content is stored locally with source metadata and sync state; bi-directional sync requires explicit opt-in and agreement-backed consent.
7. Direct messages, moderation, and private community participation remain local to each platform unless later federation work explicitly expands them.
8. Local RBAC must be reassessed before federation-sensitive actions are implemented, especially platform connections, OAuth trust, mirrored-content moderation, and publish-back.

---

## Resolution Notes

This draft chooses:

- local account ownership plus federated OAuth, not host-wide global credentials
- one shared connection-request primitive for people, communities, and platforms
- one network graph layer for linked accounts and configured platform/community/person connections
- opt-in mirrored network content instead of pure live remote fetch
- agreement-backed consent for shared authentication, sync, and publishing

Any implementation that diverges from these defaults should introduce an ADR first.

---

## Review Checklist

- Every major domain has exactly one target ownership class.
- Local platform records are clearly distinguished from network-shared linkages and mirrors.
- OAuth, agreements, and connection requests line up as one coherent federation model.
- Any future exception to these ownership defaults is captured explicitly as an ADR.
