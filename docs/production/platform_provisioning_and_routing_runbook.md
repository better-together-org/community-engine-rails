# Platform Provisioning And Routing Runbook

**Date:** April 5, 2026  
**Status:** Operator runbook baseline  
**Audience:** platform operators, deployment maintainers, release stewards  
**Purpose:** End-to-end runbook for provisioning internal managed platforms, routing domains, and aligning public registry data with tenant-schema intent

---

## Why this runbook exists

Community Engine now has enough platform-registry and domain-routing groundwork that operators can create platform records and host/domain mappings. But the intended architecture is stricter than the current implementation:

- `public` should hold the **platform registry/gateway layer**
- each internal managed platform should own its **private/local data** in its own schema
- communities should remain the row-level organizing boundary inside that platform schema
- routing should resolve the request host through the public registry/domain manifest and then activate the correct platform schema

This does **not** mean:

- every platform record is internal
- the host platform for an app instance is always the internal schema-bearing platform
- infrastructure host/steward metadata should be collapsed into the platform record itself

Today, CE does **not yet** complete the tenant-schema lifecycle. This runbook therefore distinguishes:

1. what operators can do with the current code
2. what the intended end-state operator workflow must be
3. what steps remain manual, external, or not-yet-implemented

See also:

- `../implementation/multi_tenancy/infrastructure_app_platform_topology.md`
- `../implementation/multi_tenancy/platform_registry_and_schema_boundary.md`
- `../implementation/multi_tenancy/platform_schema_migration_map.md`
- `../implementation/multi_tenancy/tenant_runtime_contract.md`
- `../implementation/multi_tenancy/platform_runtime_execution_contract.md`
- `../upgrade/multi-tenancy-upgrade.md`
- `external-services-to-configure.md`

---

## Support status matrix

| Capability | Status today | Notes |
|------------|--------------|-------|
| Create/update public `Platform` record | **Supported** | `TenantPlatformProvisioningService` can create a platform record by `host_url` |
| Auto-create one primary `PlatformDomain` from `host_url` | **Supported** | Via `sync_primary_platform_domain!` callback |
| Create primary community and optional steward/admin | **Supported, transitional** | Current implementation creates local records in the shared schema; this is not final tenant-schema provisioning |
| Resolve request hostname to `Current.platform` | **Supported** | `PlatformContextMiddleware` + `PlatformDomain.resolve` |
| Localized primary domains | **Planned, not implemented** | Current `PlatformDomain` does not encode locale |
| Campaign/vanity-domain permissioning | **Planned, not implemented** | No domain class/policy in current model |
| Per-internal-platform tenant schema creation | **Not implemented** | No schema lifecycle/tooling yet |
| Request-time schema switching | **Not implemented** | No `Current.tenant_schema` runtime yet |
| Tenant-aware jobs/mailers | **Not implemented** | Must be added before true schema isolation |
| End-to-end platform provisioning run command | **Not implemented** | Current service is transitional and insufficient for the target architecture |

---

## Canonical operator intent

When an operator says "provision a new internal managed platform," that should eventually mean:

1. create or update the platform's **public registry record**
2. define its **routing/domain manifest**
3. create and migrate its **tenant schema**
4. seed tenant-local defaults and governance primitives
5. wire external DNS / ingress / host allowlists
6. validate host resolution and fail-closed behavior

Today, only parts of that flow are implemented inside CE.

For external peer platforms, the intended operator flow is narrower:

1. create/update the public registry record
2. define trust, federation, and routing metadata as needed
3. **do not** create a CE tenant schema for that peer
4. store any accepted remote data inside the internal platform schema that ingests it

---

## Step 1 — Define the platform boundary before touching runtime

Before creating a platform, decide and record:

### Required topology classification

- which infrastructure host/steward operates the app instance
- which app instance is responsible for the platform record
- whether the platform is:
  - an internal managed platform
  - an external peer platform
- what support/stewardship relationship exists between the app instance default/host platform and the managed platform
- where community members should ask operational/support questions and how those questions are audited/responded to

### Required public-registry data

- platform name
- canonical host URL
- software variant
- privacy / network visibility defaults
- connection bootstrap state
- federation protocol / issuer URL if relevant
- translated platform metadata required for:
  - platform management
  - platform manifest participation
  - routing presentation

### Required routing data

- canonical primary domain
- additional active domains
- intended localized primary-domain variants per supported locale
- whether campaign/vanity domains are requested
- whether campaign/vanity-domain permission has been granted

### Required tenant-local expectations for internal managed platforms

- tenant schema identifier
- steward/admin seed intent
- primary community and governance assumptions
- whether invitation-only onboarding is required

If these are not explicit, the operator is likely to create a registry record that cannot be safely routed or isolated later.

---

## Step 2 — Create or update the public platform registry record

### Current code path

Today the app-side primitive is:

```ruby
BetterTogether::TenantPlatformProvisioningService.call(
  name: 'My Tenant',
  host_url: 'https://tenant.example.com',
  time_zone: 'America/Toronto',
  admin: { email: 'admin@example.com', password: 'SecurePass1!', name: 'Admin User' }
)
```

### What it does today

- finds or initializes a `Platform` by `host_url`
- writes direct platform fields such as:
  - `name`
  - `host_url`
  - `time_zone`
  - `external`
  - `host`
  - `privacy`
- triggers callback-based primary-domain sync from `host_url`
- creates a primary community
- optionally creates an admin user/person and assigns platform/community roles

### Important operator warning

This service is **transitional**:

- it is useful for the current shared-schema implementation
- it is **not** a full tenant-schema provisioning workflow
- it currently creates local records in the shared schema, which is incompatible with the final platform-private-data boundary

Use it only with that limitation in mind.

### Future required behavior

The eventual provisioning primitive must:

- create/update the public `Platform` registry record
- attach schema identity and provisioning state
- avoid silently treating shared-schema record creation as final tenant provisioning
- orchestrate tenant schema creation/migration/seed separately and explicitly

---

## Step 3 — Configure the routing/domain manifest

### Current model

Today `PlatformDomain` supports:

- `hostname`
- `primary`
- `active`

One primary domain is synced automatically from `Platform.host_url`.

### Current operator implications

Operators can currently:

- set the canonical host URL on the platform
- let the primary `PlatformDomain` be created from that URL
- manually add additional `PlatformDomain` records if needed

Operators cannot yet model, inside CE:

- locale for a domain
- primary-domain selection per locale
- domain class/type
- explicit campaign/vanity-domain permission state

### Intended routing contract

The public registry/domain manifest should eventually distinguish:

1. **canonical primary domain**
2. **localized primary-domain variants**
3. **alternate managed domains**
4. **campaign/vanity domains** that require explicit platform permission

### Operator rule until the model is expanded

Until the domain manifest grows those concepts:

- treat `PlatformDomain` as **hostname activation only**
- keep a separate operator record for:
  - intended locale/domain mapping
  - vanity/campaign-domain approval state
- do not assume CE can currently enforce locale-aware or vanity-domain routing policy by itself

---

## Step 4 — Provision the tenant schema

### Target operator flow

For the intended architecture, provisioning an internal managed platform must include:

1. create tenant schema
2. run tenant migrations
3. seed tenant-local roles and defaults
4. create tenant-local primary community
5. create tenant-local steward/admin bootstrap data

### Current reality

This lifecycle is **not yet implemented** in CE:

- no schema provisioning service
- no tenant-migration fan-out tool
- no request-time schema switching
- no tenant-aware seed runner

### Operator rule

Do **not** represent a platform as fully provisioned for schema isolation until:

- schema creation exists
- migration execution exists
- runtime schema switching exists
- validation proves the platform's private data is not sharing the host schema

External peer platforms skip this step entirely.

Until then, the platform is only provisioned at the public-registry/shared-schema-groundwork layer.

---

## Step 5 — Wire public routing outside the app

Creating a platform record inside CE is not enough to make the platform reachable.

Operators must also update the external edge:

1. **DNS**
   - create the public hostname(s)
   - confirm TTL and ownership assumptions

2. **Ingress / reverse proxy**
   - route the hostname(s) to the CE deployment
   - preserve the request `Host` header
   - preserve real client IP for Rack::Attack and auditability

3. **TLS / certificate coverage**
   - ensure the hostname is covered by certificate issuance and renewal

4. **Rails host allowlist**
   - add hostname(s) to `ALLOWED_HOSTS`
   - ensure `APP_HOST` / URL-generation settings align with the intended canonical host

If any of these are missing, CE may have a correct platform record that still cannot be reached safely or correctly.

---

## Step 6 — Validation checklist

### Current validation that operators can do today

1. Confirm the `Platform` record exists and has the intended public metadata.
2. Confirm the primary `PlatformDomain` exists and is active.
3. Confirm `PlatformDomain.resolve(host)` returns the intended platform.
4. Confirm `Current.platform` is resolved correctly on requests for that host.
5. Confirm the hostname is accepted by Rails host authorization.
6. Confirm ingress preserves the `Host` header and real client IP.

### Future validation required for true schema tenancy

1. Confirm the platform has a tenant schema.
2. Confirm request-time schema switching selects that schema.
3. Confirm tenant-local `User` / `Person` / `Community` data is isolated from other platforms.
4. Confirm jobs and mailers execute in the correct tenant context.
5. Confirm unknown, inactive, or unauthorized hosts fail closed.
6. Confirm localized primary domains route to the same platform correctly.
7. Confirm vanity/campaign domains work only when explicitly authorized.

---

## Rollback guidance

### Public-registry rollback

If the platform should not remain visible:

- disable or remove the active `PlatformDomain`
- remove the hostname from external ingress and `ALLOWED_HOSTS`
- revert the platform registry record if appropriate

### Tenant-runtime rollback

Once tenant schemas exist, rollback must become explicit and auditable:

- stop routing traffic to the tenant
- disable provisioning state in the public registry
- restore from per-tenant backup if data migration failed
- do not silently remap the hostname to a host fallback platform

The fail-safe behavior should be **closed/unavailable**, not "route somewhere else."

---

## Current gaps operators should track explicitly

The following are still open implementation tasks, not solved operator problems:

- tenant schema provisioning lifecycle
- request-time schema switching
- tenant-aware jobs and mailers
- locale-aware primary-domain routing
- campaign/vanity-domain classification and permission policy
- end-to-end per-platform migration fan-out
- automated validation of platform-to-schema isolation

These should stay visible in release planning until completed.

---

## Recommended near-term operator policy

Until full schema tenancy lands:

1. Treat new platform records as **registry/routing groundwork**, not as proof of private isolation.
2. Keep manual operator records for localized domain intent and vanity/campaign approvals.
3. Do not publish release or onboarding language that implies completed per-platform schema isolation.
4. Prefer explicit validation and fail-closed behavior over host-platform fallbacks.

---

## Values and principles guidance

- **Care:** never imply platform-private isolation where the current runtime cannot yet prove it
- **Accountability:** make every routing decision, domain approval, and platform activation auditable
- **Stewardship:** separate reversible public-registry changes from harder-to-reverse tenant data migrations
- **Solidarity:** preserve real platform autonomy rather than treating one shared host schema as "good enough"
- **Resilience:** unknown or misconfigured hosts must fail closed rather than silently landing on a fallback platform
