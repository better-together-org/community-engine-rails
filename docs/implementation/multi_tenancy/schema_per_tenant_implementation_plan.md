# Schema-Per-Tenant Multi-Tenancy Implementation Plan

**Version:** 2.0  
**Date:** March 11, 2026  
**Status:** Planning baseline  
**Depends On:** `tenant_data_ownership_matrix.md`, `tenant_runtime_contract.md`

---

## Executive Summary

Implement PostgreSQL schema-per-platform tenancy for Community Engine so that each hosted platform gets its own tenant schema, while communities remain the primary organizing boundary inside that schema.

This plan supersedes the earlier draft baseline that described CE as primarily row-scoped by `platform_id`. The current implementation is better understood as:

- one shared PostgreSQL schema
- strong community-oriented scoping patterns
- host-platform and host-community conventions
- a smaller set of platform-scoped records
- several shared or mixed infrastructure domains

The implementation strategy therefore has two prerequisites before code work begins:

1. adopt the ownership model in `tenant_data_ownership_matrix.md`
2. adopt the runtime rules in `tenant_runtime_contract.md`

No implementation phase in this document should be started until those two artifacts are approved.

---

## Target Architecture

### Tenant Boundary

- each hosted platform is assigned one PostgreSQL schema
- `public` stores fleet routing and provisioning metadata
- each tenant schema stores tenant-local application data

### In-Tenant Structure

- each tenant has one host community
- people may have personal communities inside the tenant
- other hosted communities coexist in the same tenant schema
- community scope remains the main ownership boundary for content and many operational records

### Runtime Model

- request host resolves the platform in `public`
- middleware switches to the platform’s schema
- `Current.platform` and `Current.tenant_schema` are always set in tenant requests
- `Current.community` is set only when community context is established

---

## Architecture Decisions Locked By This Plan

### Decision 1: Public Schema Contract

`public` is reserved for:

- platform routing metadata
- provisioning state
- schema lifecycle and backup metadata
- fleet-admin and support metadata that must span tenants

### Decision 2: Community Contract

Communities are the main in-schema partition for:

- host community
- personal community
- additional communities within a tenant

### Decision 3: Identity Split

`User` credentials and `Identification` remain `public-global`, while `Person` profiles remain tenant-local.

### Decision 4: Product Versus Fleet Operations

Messaging, notifications, search, and analytics are tenant-local product concerns. Fleet observability and delivery telemetry are separate cross-tenant-admin concerns.

---

## Workstreams

## Workstream 0: Planning Prerequisites

Complete before code implementation:

- confirm the ownership class of all major domains
- confirm runtime `Current` contract
- record any exceptions to the ownership matrix as ADRs

Acceptance criteria:

- no major model family lacks a target ownership class
- no implementation phase depends on an unstated runtime assumption

## Workstream 1: Public-Schema Platform Metadata

Introduce or extend `public` platform metadata to support:

- domain and subdomain routing
- schema name
- provisioning status and error state
- backup and restore metadata

Acceptance criteria:

- each tenant platform can be resolved from host metadata in `public`
- provisioning state is visible without switching into tenant schemas

## Workstream 2: Tenant Resolution And Schema Switching

Implement runtime schema selection:

- request host resolver
- middleware or elevator for schema switching
- `Current.platform` and `Current.tenant_schema`
- public-route exceptions for setup and fleet-admin workflows

Acceptance criteria:

- tenant-local requests never execute against the wrong schema
- unknown hosts fail closed
- public-only flows remain accessible without a tenant schema

## Workstream 3: Tenant Context Propagation

Implement tenant context for:

- authentication and user-to-person mapping
- background jobs
- mailers
- notifications

Acceptance criteria:

- authenticated users resolve deterministically to tenant-local people
- jobs replay with the same tenant identity
- mailers render correct tenant URLs and branding
- schema state resets cleanly after execution

## Workstream 4: Community-Scope Refactor

Refactor host-centric defaults into explicit tenant-aware community behavior:

- replace shared-schema host community fallbacks with tenant-local host community resolution
- formalize personal communities as explicit tenant-local communities
- ensure community-owned records derive ownership from tenant-local community context

Acceptance criteria:

- host community resolution is tenant-aware
- personal-community behavior is explicit and testable
- community-owned records no longer depend on shared-schema shortcuts

## Workstream 5: Tenant Data Migration

Migrate existing shared-schema data into tenant schemas according to the ownership matrix:

- seed tenant-global definitions where required
- move community-owned data into the appropriate tenant schema
- migrate host platform data into its tenant schema
- leave only approved `public-global` records in `public`

Acceptance criteria:

- migration inventory matches ownership matrix classifications
- moved data passes row-count and referential checks
- rollback path exists for each migration stage

## Workstream 6: Tenant Operations

Implement operational support for:

- schema provisioning
- migration execution across tenants
- backup and restore
- tenant health and provisioning observability
- fleet-admin support workflows

Acceptance criteria:

- schema lifecycle is automatable and auditable
- operators can inspect, back up, and restore one tenant without affecting others
- fleet-admin workflows do not depend on shared tenant tables

---

## Domain-Specific Migration Notes

The following domains require targeted migration design even though their ownership class is now chosen:

| Domain | Migration Concern |
|--------|-------------------|
| user identity / authentication boundary | map public-global credentials to tenant-local people without ambiguous joins |
| content blocks | separate tenant-global reusable assets from community-owned content |
| navigation | separate tenant-global navigation from community-owned navigation |
| integrations / OAuth | preserve tenant isolation while keeping any fleet-admin connectors out of tenant schemas |
| search / analytics | split tenant-local product indexes from cross-tenant-admin reporting and observability |

---

## Testing Strategy

### Unit Tests

- platform routing metadata validation
- tenant resolver host matching
- `Current` context setup and teardown
- public-global user to tenant-local person resolution
- tenant-aware host community and personal community resolution

### Integration Tests

- request host resolves correct schema
- tenant-local controllers operate only inside active schema
- authenticated user resolves to the correct tenant-local person profile
- jobs and mailers preserve tenant context
- public-only routes remain outside tenant schemas

### Migration Tests

- host platform migration from shared schema to tenant schema
- representative community-owned record migrations
- seed/bootstrap of tenant-global definitions
- rollback and retry behavior for failed tenant provisioning

### Security Tests

- unknown-host fail-closed behavior
- no cross-tenant data leakage
- no accidental fallback to `public` for tenant-local writes
- cross-tenant admin operations isolated from end-user routes
- authenticated users cannot read or mutate tenant-local data without a valid tenant-local person mapping

---

## Rollout Sequence

1. Approve ownership matrix and runtime contract.
2. Record ADRs for any deviation from the ownership matrix defaults.
3. Add public-schema platform routing and provisioning metadata.
4. Implement tenant resolution and schema switching.
5. Propagate tenant context to jobs and mailers.
6. Refactor host-community and personal-community behavior to be tenant-aware.
7. Execute staged data migration into tenant schemas.
8. Enable backup, restore, and fleet-admin support tooling.

Production rollout should migrate the host platform first in a controlled staging-tested path before onboarding additional hosted platforms.

---

## Success Criteria

- hosted platform requests resolve to exactly one tenant schema
- communities remain the primary in-tenant organizing boundary
- personal communities are explicit and testable
- no end-user workflow depends on shared-schema host-community shortcuts
- fleet-admin operations work without reintroducing shared tenant tables

---

## Related Documents

- `docs/assessments/multi_tenancy_gap_assessment_2026-03-11.md`
- `docs/implementation/multi_tenancy/tenant_data_ownership_matrix.md`
- `docs/implementation/multi_tenancy/tenant_runtime_contract.md`
