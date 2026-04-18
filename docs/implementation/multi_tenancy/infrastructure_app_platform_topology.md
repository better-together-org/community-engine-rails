# Infrastructure, App Instance, And Platform Topology

**Date:** April 5, 2026  
**Status:** Architecture reconciliation baseline  
**Purpose:** Define the relationship between infrastructure hosts, CE app instances, internal managed platforms, external peer platforms, and community governance

---

## Why this document exists

The tenancy work uncovered a persistent vocabulary problem:

- `host` can mean infrastructure host, app-level default platform, or governance steward
- `platform` can mean a managed internal tenant, an external peer, or a public registry record
- a routed app instance can be operated by one steward while supporting multiple communities and connected platforms

If these layers stay blurred, schema tenancy, federation, routing, bot protection, and stewardship/accountability work all land on the wrong abstraction.

This document separates those layers and defines how they relate.

It complements:

- `platform_registry_and_schema_boundary.md`
- `platform_runtime_execution_contract.md`
- `federation_registry_and_tenant_boundary.md`
- `../../production/platform_provisioning_and_routing_runbook.md`

---

## Executive summary

Community Engine needs four distinct layers:

| Layer | What it is | What it is not |
|------|-------------|----------------|
| Infrastructure host / steward | The server, operator, network links, secrets, uptime, observability, and operational accountability layer | Not a tenant schema |
| App instance node | One CE deployment plus its local DB/runtime boundary, edge routing, TLS, bot protection, and app-local support context | Not automatically a managed platform |
| Managed platform | A `better_together_platforms` registry record representing either an internal managed platform or an external peer | Not the same thing as the physical host or app instance |
| Community | The row-level organizing and permission boundary inside an internal platform schema | Not the replacement for platform or infrastructure stewardship |

### Core rule

Only **internal managed platforms** get tenant schemas in CE.

External peer platforms:

- remain public registry records
- participate in federation/trust/routing contracts
- do **not** get their own CE tenant schemas
- have their accepted remote data stored inside the internal platform schema that ingested it, with explicit provenance

---

## The four-layer model

## 1. Infrastructure host / steward layer

This layer covers:

- physical or virtual servers
- host-level networking and overlays
- secrets, service accounts, bot identities, tokens, and API keys at the infrastructure boundary
- observability, backups, incident response, and capacity stewardship
- who is accountable for keeping the system healthy

Examples in BTS operations can include servers such as:

- `bts-0`
- `bts-4`
- `bts-5`

and network paths such as:

- LAN
- Headscale
- Pangolin

### What belongs here

- server federation and private-network relationships
- uptime and maintenance accountability
- fleet-level service inventory
- infra-scoped bot/service identities
- host-level security controls and ingress protections

### What does not belong here

- tenant-local people, communities, posts, memberships, or safety data
- the assumption that one server equals one platform
- the assumption that the "host platform" for governance is the same as the internal schema-bearing platform

---

## 2. App instance node layer

An app instance node is one deployed CE runtime plus its local database boundary.

This layer covers:

- the running Rails app
- the connected database/runtime boundary
- DNS, TLS, ingress, and host allowlisting
- bot protection and abuse prevention at public ingest points
- local support and operational workflows
- instance-level auth/integration configuration

### Key rule

An app instance node may:

- manage one or more **internal** platforms
- maintain registry records for **external** peer platforms
- federate with other app instances
- be operated by a steward/platform that is not identical to every internal platform it hosts

### Important consequence

The app instance is the place where:

- request routing becomes runtime context
- public ingest protections apply
- tenant schema switching eventually occurs
- operational support needs to remain auditable and accountable

But the app instance itself is still not the same thing as a managed platform.

---

## 3. Managed platform layer

This layer lives in `better_together_platforms` and has two modes:

### Internal managed platforms

These are platforms whose private/local data is managed by this CE app instance.

They:

- are represented in the public registry
- carry tenant schema identity
- own tenant-local people, content, safety state, invitations, and communities
- participate in federation as local schema-bearing platforms

### External peer platforms

These are remote platforms known to this app instance for trust, federation, mirroring, OAuth, or other cross-platform relationships.

They:

- are represented in the public registry
- may carry rich trust and routing metadata
- do **not** carry tenant schema identity in CE
- do **not** own local tenant tables inside this CE instance

---

## 4. Community layer

Communities remain the row-level organizing boundary inside an internal platform schema.

They are where:

- membership and participation rules are enforced
- community-private visibility is gated
- local democratic/governance workflows can happen
- people can contribute, ask questions, and help guide platform operation

### Important consequence

Community governance should remain visible and meaningful without requiring community members to have infrastructure-host privileges or app-instance operator access.

---

## Relationship model

The intended relationship chain is:

1. **Infrastructure host/steward** operates
2. **App instance node** which manages
3. **Internal managed platform(s)** which contain
4. **Community rows and local people/content**

In parallel, the app instance also knows about:

- **external peer platforms**
- **server/network relationships**
- **app-instance-to-app-instance relationships**

Those connected surfaces interact, but they are not the same record type and should not be forced into one overloaded `Platform` meaning.

---

## Federation lanes across the topology

## 1. Server federation

This is infrastructure-to-infrastructure connectivity:

- private overlays
- routable links
- machine identities
- observability and operational reachability

This belongs primarily to the infrastructure/steward layer.

## 2. App-instance federation

This is deployment-to-deployment relationship handling:

- webhook/API reachability
- TLS/routing trust
- instance-level public ingress and egress decisions
- delivery reliability and operational coordination

This belongs primarily to the app instance layer.

## 3. Platform federation

This is managed-platform-to-managed-platform relationship handling:

- platform registry/trust
- content mirroring
- OAuth/account linking
- explicit agreements and publish-back choices

This belongs primarily to the public registry and tenant-local policy layers.

### Key rule

Server federation, app-instance federation, and platform federation are related, but they must not be collapsed into one boolean "connected" state.

---

## Stewardship and accountability model

The architecture should preserve all of these at once:

### Infrastructure stewardship

- who keeps the server healthy
- who manages secrets, backups, and uptime
- who is responsible for security posture and bot protection at the edge

### Platform stewardship

- who manages platform defaults, public routing identity, invitation policy, and community support commitments
- who is accountable for the stability of the platform's community infrastructure

### Community participation and contribution

Hosted communities need meaningful and auditable ways to:

- ask questions
- report issues
- understand operational/support boundaries
- contribute to the effective running of the platform
- see how stewardship decisions affect their lived experience

That participation layer must not require collapsing community governance into infrastructure-admin privilege.

---

## BTS reference implications

For BTS-operated client infrastructure, this architecture can support a pattern like:

- BTS-operated servers provide the infrastructure host/steward layer
- a CE app instance runs on that infrastructure
- the local app instance may have a host/default platform for support and accountability
- the same app instance may also manage one or more internal client/community platforms
- those managed platforms can federate with external peers and with other BTS- or client-operated instances

In this pattern:

- the app instance's support/steward platform is not automatically identical to every internal managed platform
- hardware stewardship is not the same thing as tenant ownership
- client/community autonomy still depends on preserving internal platform and community boundaries

---

## Implementation implications

### 1. `Platform.host` must stay narrow

`Platform.host` can remain a local app/default-host convenience, but it must not be treated as:

- proof that a platform is internal
- proof that a platform owns a tenant schema
- proof that the platform represents the infrastructure steward

### 2. `Platform.internal?` is the schema-tenancy decision

For schema tenancy, the decisive question is:

> Does this CE app instance manage private local data for this platform in a tenant schema?

That is what `internal?` should answer.

### 3. Topology metadata needs its own home

The system will eventually need an explicit representation for:

- infrastructure hosts
- app instances
- instance-to-host relationships
- instance-to-platform stewardship/support relationships

That should not be improvised through overloaded platform flags.

### 4. Provisioning must branch early

Provisioning should first determine whether a new registry record is:

- an internal managed platform
- an external peer platform

Then it should follow different flows.

### 5. Runtime fail-closed behavior must respect the topology

Tenant-local routes must fail closed when they resolve to:

- an external-only platform record
- an ambiguous host-default path
- a platform with no valid tenant schema

---

## Recommended implementation order

1. Keep internal/external platform semantics explicit in code and docs.
2. Add a canonical topology reference for infrastructure hosts, app instances, and stewardship/support relationships.
3. Narrow host-platform fallbacks so they are used only for explicitly public/app-default surfaces.
4. Add explicit app-instance/infrastructure models or inventories rather than overloading `Platform`.
5. Extend operator runbooks so community members and platform stewards can see where to ask questions and how support/accountability flows work.

---

## Design guardrails

- **Care:** do not mislead communities about who controls infrastructure versus who governs their local platform space
- **Accountability:** make steward, operator, and platform-support responsibilities legible and auditable
- **Solidarity:** preserve meaningful autonomy for hosted communities instead of collapsing all power into host-wide defaults
- **Empowerment:** give people real ways to ask questions and contribute to platform health without needing full operator privileges
- **Stewardship:** avoid overloading one model with infrastructure, runtime, and community-governance meanings

