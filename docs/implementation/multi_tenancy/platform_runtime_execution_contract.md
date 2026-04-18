# Platform Runtime Execution Contract

**Date:** April 5, 2026  
**Status:** Architecture-to-implementation contract  
**Purpose:** Define the concrete runtime behavior for requests, jobs, mailers, and rendering under platform-schema tenancy

---

## Why this document exists

The existing tenancy docs already describe the intended high-level model:

- platform routing resolves through the public registry
- each internal managed platform owns private/local data in its own schema
- communities remain row-level organizing boundaries inside that schema

What was still missing was the **execution contract** for the runtime surfaces that must actually honor that boundary:

- Rack requests
- controllers and URL generation
- background jobs
- mailers
- renderer / cache / ActiveStorage context

This document defines that contract and names the failure modes in the current implementation that must be removed.

It complements:

- `infrastructure_app_platform_topology.md`
- `tenant_runtime_contract.md`
- `platform_registry_and_schema_boundary.md`
- `platform_schema_migration_map.md`
- `../../production/platform_provisioning_and_routing_runbook.md`

---

## Executive summary

### Intended runtime rule

Every execution path that touches platform-owned data must have:

1. a resolved **public platform registry record**
2. for internal platforms, a resolved **tenant schema identity**
3. a fail-closed rule when either is missing or unauthorized

Runtime context should also avoid confusing:

- the infrastructure host/steward
- the app instance default/host platform
- the routed internal managed platform

Those are related but distinct topology layers. See `infrastructure_app_platform_topology.md`.

### Required `Current` contract

For tenant-aware execution, the runtime should carry at least:

| Field | Meaning |
|-------|---------|
| `Current.platform` | Public platform registry record resolved from host or explicit job/mailer context |
| `Current.platform_domain` | Resolved domain-manifest record, when execution started from a routed host |
| `Current.tenant_schema` | Active tenant schema for internal platform-owned private/local data |
| `Current.person` | Current tenant-local person |
| `Current.governed_agent` | Current actor for policy/governance checks |

Today CE only carries a subset of this contract.

---

## Current implementation baseline

### Requests today

Current request execution does this:

- `PlatformContextMiddleware` resolves `PlatformDomain.resolve(request.host)`
- `Current.platform` is set from the resolved domain or falls back to `host: true`
- `BetterTogether::ApplicationController` repeats that context setup and configures `ActiveStorage::Current.url_options`

That fallback only identifies a default platform record. It does **not** prove the resolved platform is an internal tenant with a schema.

### Jobs today

Current jobs are mixed:

- some jobs accept `platform_id`
- some jobs set `Current.platform` manually
- no job contract carries `tenant_schema`
- no job wrapper performs schema switching before data access

### Mailers today

`BetterTogether::ApplicationMailer` currently resolves mail context from:

1. explicit `@platform`
2. `Current.platform`
3. host-platform fallback or `BetterTogether.base_url`

This is enough for platform-aware URL generation in a shared schema, but not enough for tenant-schema execution.

### Shared failure pattern

Across requests, jobs, mailers, helpers, and policies, the current runtime still relies heavily on:

- `Current.platform || Platform.find_by(host: true)`
- `Community.find_by(host: true)`

Those fallbacks are incompatible with trustworthy schema tenancy.

---

## Request execution contract

### Target flow

For every routed request:

1. read the inbound host
2. resolve that host against the public platform registry/domain manifest
3. verify the matched domain is:
   - active
   - authorized for the platform
   - valid for the requested routing mode
4. load the platform registry record from `public`
5. verify whether the resolved platform is internal or external
6. if internal, resolve the platform's `tenant_schema`
7. switch into that tenant schema **before** application/controller logic reads platform-owned data
8. set:
    - `Current.platform`
    - `Current.platform_domain`
    - `Current.tenant_schema`
9. configure tenant-aware URL/rendering helpers
10. on request end, reset all runtime context

### Fail-closed rules

Requests must fail closed when:

- host is unknown
- domain record is inactive
- domain is not authorized for the platform
- an internal platform has no valid tenant schema
- schema switch fails
- a tenant-local route resolves to an external-only platform record

Fail closed means:

- return unavailable / not found / explicit platform-routing failure
- do **not** silently route to the host platform
- do **not** silently keep executing in `public`

### Current code changes required

The current request stack must be changed in at least these places:

- `PlatformContextMiddleware`
- `BetterTogether::ApplicationController#set_current_platform_context`
- any helper or policy that falls back to `host: true`

The host-platform fallback can remain only for explicitly host-global/public-registry surfaces that are designed to run in `public`.

---

## Controller and rendering contract

Once request routing has selected a tenant schema:

- controller queries for platform-owned private data must execute inside that schema
- `default_url_options` must reflect the resolved routed domain/platform
- `ActiveStorage::Current.url_options` must use the resolved platform/domain host
- helpers must not discover platform context by falling back to host-platform globals

### Explicit exception rule

Some controllers may still be intentionally public/global, for example:

- provisioning before tenant creation
- fleet support/admin surfaces
- peer platform discovery/bootstrap

Those surfaces must declare themselves as public-registry execution, not reach that mode accidentally via missing tenant context.

---

## Job execution contract

### Target flow

Every background job that touches internal platform-owned data must carry:

- `platform_id`
- `tenant_schema`
- optional `platform_domain_id` if routed-host semantics matter
- optional `community_id` when the job is community-specific

Job execution must:

1. load the public platform record
2. verify the tenant schema matches the registry record
3. switch into that tenant schema
4. set `Current.platform`
5. set `Current.tenant_schema`
6. set any community/person context explicitly if required
7. perform work
8. reset context at the end

### Fail-closed rules

Jobs must fail closed when:

- `platform_id` is missing for platform-owned work
- `tenant_schema` is missing or mismatched
- schema switch fails
- a supposedly tenant-local job is invoked from ambiguous host-global assumptions

Federation ingest and remote sync jobs still run inside the internal tenant schema that accepted the data. External peer platforms do not become job-local schemas of their own inside CE.

### Current code changes required

At minimum:

- define a tenant-aware `ApplicationJob` helper or concern
- update jobs like `NotificationCacheWarmingJob` to carry `tenant_schema`, not just `platform_id`
- remove implicit shared-schema assumptions from cache warming, metrics, sync, and renderer-backed jobs

---

## Mailer execution contract

### Target flow

Every mailer that renders platform-owned content must have an explicit platform runtime context:

- `platform_id`
- `tenant_schema`
- optional `platform_domain_id` or resolved host URL if email must use a specific routed domain

Mailer execution must:

1. load the public platform record
2. verify and switch to the tenant schema before loading tenant-local records
3. set `Current.platform`
4. set `Current.tenant_schema`
5. compute `default_url_options` from the intended routed platform domain
6. set `ActiveStorage::Current.url_options` consistently
7. reset context after rendering

### Fail-closed rules

Mailers must not:

- silently fall back to `Platform.find_by(host: true)` for tenant-local emails
- render a tenant-local email from the wrong schema
- default to a global/base URL when a tenant-local routed host is required

### Current code changes required

`BetterTogether::ApplicationMailer` needs a tenant-aware replacement for:

- `@platform ||= Current.platform || BetterTogether::Platform.find_by(host: true)`

Host fallback should remain only for truly host-global mail surfaces, and those should be explicit.

---

## Helper / policy / model fallback contract

### Rule

Any code path that accesses platform-owned private/local data must prefer:

1. explicit context
2. verified `Current.platform` + `Current.tenant_schema`

It must not silently substitute:

- host platform
- host community
- first platform in the database

### Current known hotspots

Examples already present in the codebase:

- `ApplicationController#set_current_platform_context`
- `PlatformContextMiddleware#call`
- `ApplicationMailer#set_locale_and_time_zone`
- `NotificationCacheWarmingJob#with_platform_context`
- content models that auto-assign `platform_id` from `Current.platform || host platform || first platform`
- helper/policy code using `Platform.find_by(host: true)` and `Community.find_by(host: true)`

### Migration rule

For tenant-schema work:

- host fallbacks must be removed from tenant-local execution paths
- true host-global/public-registry execution paths must be explicitly labeled and isolated

---

## Cache, URL, and ActiveStorage contract

Schema tenancy affects rendering, fragment keys, and asset URLs.

### Required behavior

- fragment cache keys for platform-owned data must be schema/platform aware
- renderer-backed jobs must set the same tenant/runtime context as web requests
- URL helpers must point at the resolved routed domain for that platform
- `ActiveStorage::Current.url_options` must be set from the intended platform domain, not a host fallback

### Current limitation

The current platform-aware rendering work uses `Current.platform` plus host fallback. That is useful groundwork, but not sufficient once schemas diverge.

---

## Runtime rollout sequence

### Phase 1 — add runtime identity

- extend `Current` with `tenant_schema`
- add schema identity to public platform registry records
- define a single runtime resolver service for host -> platform -> tenant schema

### Phase 2 — request path

- update middleware and controller context setup
- remove silent host-platform fallback from tenant-local request flow
- add fail-closed error path for unknown/misconfigured hosts

### Phase 3 — jobs and mailers

- add tenant-aware job helper
- add tenant-aware mailer helper
- migrate existing jobs/mailers that currently carry only `platform_id` or rely on host fallback

### Phase 4 — helper/model/policy cleanup

- remove shared-schema host fallbacks from tenant-local helpers, models, and policies
- isolate true public-registry/host-global surfaces explicitly

### Phase 5 — validation

- request host resolution tests
- unknown-host fail-closed tests
- schema-switch tests
- job and mailer tenant-context tests
- cache/URL/ActiveStorage tests under multiple platform domains

---

## Success criteria

This contract is satisfied when:

1. every tenant-local request resolves a platform and schema before app logic
2. every tenant-local job and mailer carries explicit schema identity
3. unknown or invalid hosts fail closed
4. tenant-local surfaces no longer rely on host-platform fallback
5. URL generation, rendering, and cache behavior stay correct under multiple routed platform domains

---

## Values and principles guidance

- **Care:** do not let runtime ambiguity leak one platform's private data into another platform's execution path
- **Accountability:** runtime context must be explicit enough to audit why a request, job, or mailer ran in a given platform/schema
- **Stewardship:** remove shared-schema shortcuts deliberately and in waves, not by silently preserving them under a new name
- **Solidarity:** platform autonomy depends on explicit runtime boundaries, not just model-level intent
- **Resilience:** routing or schema errors must fail closed rather than silently collapsing back to the host platform
