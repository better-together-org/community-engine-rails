# Tenant Runtime Contract

**Date:** March 11, 2026  
**Status:** Draft architecture baseline  
**Purpose:** Canonical request, context, and execution contract for schema-per-platform tenancy

---

## Summary

This document defines how CE should behave at runtime once schema-per-platform tenancy is introduced.

It assumes:

- the ownership rules in `tenant_data_ownership_matrix.md`
- one tenant schema per hosted platform
- communities as the primary in-schema structure

The contract covers:

- request tenant resolution
- schema switching
- `Current` context
- job and mailer propagation
- cross-tenant admin behavior

---

## Request Resolution

### Request Input

Each incoming request is resolved from:

- request host
- optional subdomain
- path and route

### Resolution Rules

1. Look up the request host in `public.better_together_platforms`.
2. Match exact custom domain first.
3. Match known subdomain + base domain second.
4. Load the target platform’s routing metadata from `public`.
5. Resolve the tenant schema name from that platform record.
6. Switch to the tenant schema before controller logic runs.

### Public-Schema Exceptions

The following request classes run in `public` without switching to a tenant schema:

- provisioning and setup flows before a tenant exists
- fleet-admin and support routes that explicitly operate across tenants
- unknown-host fallback handling

Unknown hosts must not silently fall through to arbitrary tenant data.

---

## Current Context Contract

### Required `Current` Fields

| Field | Meaning |
|-------|---------|
| `Current.platform` | Public-schema platform metadata for the resolved tenant |
| `Current.tenant_schema` | Active tenant schema name |
| `Current.community` | Current community in tenant context when route or UI establishes one |
| `Current.person` | Current authenticated person for the tenant |

### Context Rules

- `Current.platform` is always set for tenant-local requests.
- `Current.tenant_schema` is always set together with `Current.platform`.
- `Current.community` is optional and only set when route context or selection logic establishes it.
- `Current.person` is tenant-local and must be loaded after schema switching.

### Host Community Rules

- Each tenant has exactly one host community.
- The host community is the platform-default community inside the tenant.
- Flows that previously fell back to "host community in shared schema" must instead resolve host community within the active tenant schema.

### Personal Community Rules

- A person may have exactly one personal community inside a tenant.
- Personal communities are explicit community records, not hidden context.
- Personal calendars and similar person-owned resources resolve through the person’s personal community.

---

## Community Selection Rules

CE must distinguish between tenant context and community context.

### Tenant Context

Tenant context is established by host/domain routing.

### Community Context

Community context is established by one of:

- route nesting under a community resource
- explicit community selector in the UI
- record ownership when operating on a community-owned record
- host-community default only where the feature is intentionally tenant-wide and no explicit community is selected

The host community must not become a universal silent fallback for every record type.

---

## Background Jobs

### Enqueue Contract

Every tenant-local job payload must include:

- platform identifier or schema identifier sufficient to restore tenant context
- optional community identifier if the job acts on a community-owned record

### Execution Contract

Before job work begins:

1. Load platform metadata from `public`.
2. Switch to the tenant schema.
3. Set `Current.platform` and `Current.tenant_schema`.
4. Set `Current.community` if the job is community-specific.

After execution:

- reset schema state
- clear `Current` context

Job retries must preserve tenant identity and community identity.

---

## Mailers And Notifications

### Mailers

Mailers must render in tenant context so that:

- lookups happen inside the correct tenant schema
- links use the tenant’s domain
- platform branding is tenant-specific

### Notifications

Notifications should be treated as tenant-local unless explicitly marked as fleet-admin notifications.

If notification delivery infrastructure needs global storage, that must be modeled explicitly and not assumed from the current shared-schema implementation.

---

## Cross-Tenant Administration

Cross-tenant operations are not normal tenant requests. They run in a dedicated fleet-admin context.

### Allowed Cross-Tenant Operations

- tenant inventory
- provisioning and backup status
- support diagnostics
- fleet-level reporting and observability

### Cross-Tenant Query Pattern

Cross-tenant operations must iterate or aggregate deliberately. They must not assume shared-table visibility after tenant schemas are introduced.

If product-level global search is required, it should use a dedicated cross-tenant index or reporting pipeline instead of ad hoc schema iteration in request paths.

---

## Failure And Safety Rules

- Unknown or invalid hosts must fail closed.
- Missing tenant schema must fail with a provisioning or unavailable state, not fall into another tenant.
- Jobs missing tenant context must raise clear errors and not run in `public` by accident.
- Community-owned mutations without explicit or derivable community context must fail closed.

---

## Interface Additions Implied By This Contract

The implementation plan should assume these additions:

- `Platform` routing fields in `public` for domain/subdomain/schema mapping
- runtime support for `Current.platform`, `Current.tenant_schema`, and `Current.community`
- tenant-aware middleware for request switching
- tenant-aware job and mailer context wrappers

---

## Review Checklist

- A tenant request can be traced from host resolution to schema switch to `Current` context.
- A community-owned request can be traced from tenant context to explicit community context.
- A queued job can be replayed with the same tenant and community identity.
- Fleet-admin operations are defined separately from tenant-local behavior.
