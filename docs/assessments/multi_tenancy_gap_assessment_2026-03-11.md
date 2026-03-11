# CE Multi-Tenancy Gap Assessment

**Date:** March 11, 2026  
**Assessment Type:** Branch, PR, and architecture gap assessment  
**Repository:** better-together-org/community-engine-rails  
**Scope:** Existing multi-tenancy work in branches, PRs, docs, plans, and current implementation

---

## Executive Summary

Community Engine is not yet implemented as a schema-per-platform multi-tenant system. The current codebase is still a single PostgreSQL schema with a mix of:

- host-platform and host-community conventions
- community-scoped records inside the shared schema
- a smaller set of platform-scoped records and memberships
- several global or effectively shared tables

The main existing multi-tenancy branch is `feat/multi-tenant`, exposed as draft PR `#1215` titled `WIP multi-tenant`. As of March 11, 2026, that PR is planning-only. Its sole change is `docs/implementation/multi_tenancy/schema_per_tenant_implementation_plan.md`; there is no corresponding Apartment integration, tenant resolver, schema provisioning, migration support, or runtime tenant switching in the codebase.

The current docs often describe CE as a "multi-tenant" platform because the domain model supports `Platform -> Community -> Person` relationships and separate platform/community memberships. That is a useful conceptual foundation, but it overstates the current isolation model. In implementation terms, CE is presently a single-schema app with mixed record scoping, not a schema-isolated hosted-platform architecture.

For the target direction described for hosted platforms, the strongest reusable foundation already in the repo is the existing community-centric data model. Communities already act as the main content, geography, membership, and workflow boundary. That makes a schema-per-platform plus intra-schema community scope model plausible. The largest gap is not community modeling; it is platform-level isolation, request routing, operational lifecycle, and a clean definition of what remains in `public` versus what moves into tenant schemas.

---

## Assessment Scope And Method

This assessment compares four sources of truth:

1. Existing branches and PRs related to multi-tenancy
2. Existing implementation plans and assessment documents
3. Current Rails models, policies, and schema
4. The target architecture:
   - one PostgreSQL schema per hosted platform
   - communities as the primary structure inside each platform schema
   - tenant data scoped to a community within that schema, whether host community, personal community, or another community on the platform

The goal is to distinguish clearly between:

- documented intent
- code that exists today
- architectural elements that can be reused
- areas that require redesign before implementation

---

## Artifact Inventory

### Branches And PRs

| Artifact | Status | What Exists | Assessment |
|----------|--------|-------------|------------|
| `feat/multi-tenant` | local + remote branch | One planning commit: `WIP multi-tenant` | Planning-only |
| PR `#1215` `WIP multi-tenant` | open draft | Adds only `docs/implementation/multi_tenancy/schema_per_tenant_implementation_plan.md` | Planning-only |

### Primary Planning And Documentation Artifacts

| Artifact | Type | Key Claim | Assessment |
|----------|------|-----------|------------|
| `docs/implementation/multi_tenancy/schema_per_tenant_implementation_plan.md` | implementation plan on `feat/multi-tenant` | Proposes Apartment-based schema-per-tenant architecture | Closest existing plan, but not implemented and partially misstates current state |
| `docs/developers/systems/community_social_system.md` | system doc | Describes "multi-tenant platform architecture" and `Platform -> Community -> Person` hierarchy | Conceptually useful, but describes logical hierarchy more than actual schema isolation |
| `docs/assessments/platform_management_system_review.md` | assessment doc | Claims "comprehensive multi-tenancy support with proper data isolation" | Overstates current implementation; reflects model/policy separation, not tenant-schema isolation |
| `docs/implementation/current_plans/community_social_system_implementation_plan.md` | implementation plan | Builds organizer and moderation flows around host-community patterns | Useful for intra-platform community scope, not platform isolation |

### Important Observation

There is currently no evidence in the app, config, gem manifests, or runtime code of:

- `ros-apartment`
- `Apartment::Tenant`
- tenant-aware middleware or elevators
- schema provisioning jobs
- tenant-aware Sidekiq or mailer context
- cross-schema migration tooling

That means CE currently has **documentation about multi-tenancy** and **one draft plan for schema-per-tenant tenancy**, but not an implemented schema-based tenancy stack.

---

## Current Implementation Reality

## 1. Database And Runtime Isolation Model

Current state:

- Single PostgreSQL schema
- No tenant schema switching
- No request-time tenant resolution by domain/subdomain
- No platform-specific schema lifecycle
- No tenant-aware job or mailer execution context

Representative evidence:

- `better_together_platforms` and `better_together_communities` both live in the same schema in `spec/dummy/db/schema.rb`
- `Platform` still uses a single `url` field, a `host` flag, and a generated primary community
- `PrimaryCommunity` auto-creates a `Community` record for models that `has_community`
- `Page` still defaults to the host community when no `community_id` is assigned

Implication:

The live architecture is not "schema-per-platform with communities inside schema." It is "single schema with host-centric defaults and community-oriented scoping."

## 2. Platform Model Semantics

The `Platform` model already contains some concepts that fit hosted-platform tenancy:

- unique platform record
- platform memberships
- invitation settings
- branding and CSS blocks
- a primary community via `has_community`

But its current semantics are still shaped around one shared app:

- `PlatformHost` enforces a single `host: true` record
- `Platform#url` is implemented via route helpers, not host/domain mapping for isolated tenant dispatch
- a platform always points at a `community_id`, meaning the "platform owns a primary community" pattern is central
- there is no `schema_name`, `domain`, `subdomain`, or provisioning lifecycle in the current implementation

Assessment:

`Platform` is a viable anchor for schema-per-platform tenancy, but it is not yet acting as a tenant boundary.

## 3. Community Model Semantics

The `Community` model is the strongest existing boundary in the current app. It already supports:

- membership
- privacy
- creator ownership
- invitations
- calendars
- event hosting
- community-scoped related resources

This is a strong match for the target intra-schema model. Inside one tenant schema, communities can plausibly remain the primary organizing boundary for:

- host community
- personal community
- additional hosted communities

Assessment:

The repo is much closer to "community-scoped data inside one platform" than it is to "platform isolation across many hosted platforms."

## 4. Person Model Semantics

`Person` currently mixes several concerns:

- membership in both platforms and communities
- its own primary community via `has_community`
- personal resources such as calendars, messages, reports, notifications, and integrations

This is important for the target design because it already implies a concept close to a personal or home community. However, today it still lives inside the shared schema with no tenant boundary around it.

Assessment:

The existing person model can support "your personal community inside your platform schema," but only after tenant isolation is added and personal-community semantics are made explicit in the architecture.

---

## Current Scope Matrix

The table below summarizes the current implementation shape, not the intended future state.

| Domain / Record Type | Current Scope Shape | Notes |
|----------------------|---------------------|-------|
| `Platform` | platform-scoped metadata in shared schema | One table for all platforms; still host-centric |
| `Community` | community-scoped in shared schema | Main organizing boundary today |
| `Person` | mixed | Has `community_id`, plus platform/community memberships |
| `PersonCommunityMembership` | community-scoped membership | Joinable pattern is community-based |
| `PersonPlatformMembership` | platform-scoped membership | Separate platform membership exists |
| Calendars, geography, infrastructure, places | community-scoped | Many tables carry `community_id` directly |
| Pages | mostly community-scoped | Can default to host community |
| Webhook endpoints | community-scoped | Explicit `community_id` usage exists |
| Platform blocks / platform invitations | platform-scoped | Existing platform-level resources |
| Roles / resource permissions | effectively shared/global definitions | Not tenant-schema aware today |
| Navigation areas / items | mixed or shared | Not cleanly tenant-bound today |
| Conversations / messages / notifications | mixed or shared | Not currently modeled as tenant-schema isolated |
| Content blocks | mixed | Shared block system; tenant boundary not encoded at schema level |

### What This Means

The current app is not primarily row-scoped by `platform_id`. It is more accurate to say:

- many domain records are already community-scoped
- some administrative and membership records are platform-scoped
- some shared infrastructure tables are global within the shared schema

This matters because the draft schema-per-tenant plan currently states that the app stores all data in `public` with row-level `platform_id` scoping. That is not an accurate description of the current implementation. The present model is much more community-centric than that statement implies.

---

## Gap Analysis Against Target Architecture

## 1. Tenant Boundary Definition

### Target

- each hosted platform has its own PostgreSQL schema
- schema contains all tenant data for that hosted platform
- communities provide structure inside that schema

### Current Gap

- no tenant schema exists
- no tenant lifecycle exists
- no request routing exists for tenant selection
- no clear contract exists for which records stay in `public`

### Assessment

This is the largest architectural gap.

## 2. Routing And Tenant Resolution

### Target

- domain or subdomain selects a platform tenant
- app switches to that tenant schema before normal app logic runs

### Current Gap

- no domain/subdomain tenant resolution service
- no Rack middleware or elevator
- no schema switch context
- current routing remains host-oriented

### Assessment

This must be designed before implementation work begins, because it affects controllers, mailers, jobs, URLs, and deployment.

## 3. Public Schema Versus Tenant Schema Placement

### Target

A minimal `public` schema should hold only globally required metadata and cross-tenant coordination records.

### Current Gap

The existing draft plan suggests leaving only `better_together_platforms` in `public`, but the repo has not yet made the following decisions explicit:

- whether platform organizer accounts are global or tenant-local
- whether `Person` should exist only inside tenant schemas or also in `public`
- whether roles and permissions are seeded per tenant or shared globally
- whether OAuth or external integrations are tenant-local or cross-tenant
- whether notifications, metrics, and search indexes are tenant-local or centralized

### Assessment

The current draft is directionally useful but underspecified at the boundary where the hardest migrations will happen.

## 4. Intra-Schema Community Scope

### Target

Within one platform schema:

- host community
- personal community
- other communities

should all be first-class community-scoped boundaries for data.

### Current Strength

This is where the current codebase is strongest:

- communities already organize many domain records
- a host-community concept already exists
- people already have primary communities
- policies and flows already reason about community-level membership and access

### Current Gap

- "personal community" is present through primary-community mechanics, but not yet formalized as a tenancy contract
- some domains remain mixed or shared and would need explicit scoping rules
- several models still fall back to host-community assumptions rather than using an explicit current tenant plus current community model

### Assessment

The community model is the part to preserve, not replace.

## 5. Background Jobs, Mailers, And Operations

### Target

- jobs inherit tenant schema context
- mailers render platform-specific URLs and branding
- migrations, backups, and restore workflows operate per tenant schema

### Current Gap

- no job middleware for tenant context
- no mailer tenant context
- no schema lifecycle tasks
- no per-tenant migration, backup, restore, or repair tooling

### Assessment

The operational layer is almost entirely absent today and would need to be built from scratch.

## 6. Cross-Tenant Administration

### Target

The system still needs an answer for:

- global search
- fleet reporting
- support/admin operations across all hosted platforms
- emergency remediation across many tenant schemas

### Current Gap

The current implementation assumes one shared database schema, so many admin and reporting patterns are implicitly cross-platform already. Moving to per-platform schemas will make those workflows harder unless a deliberate cross-tenant strategy is defined.

### Assessment

This is easy to underestimate and should be considered a first-class design problem, not a follow-up detail.

---

## Evaluation Of Existing `feat/multi-tenant` Plan

## What The Existing Plan Gets Right

- It chooses the correct high-level direction: schema-per-tenant isolation for hosted platforms.
- It recognizes the need for:
  - domain/subdomain routing
  - schema provisioning
  - tenant-aware jobs and mailers
  - migration and backup tooling
  - host-platform migration out of the shared schema
- It treats operational lifecycle as part of the implementation, not an afterthought.

## Where The Existing Plan Is Weak Or Inaccurate

### 1. Current-State Misread

The plan says current CE stores data in `public` with row-level `platform_id` scoping. That is not the dominant pattern in the codebase. The current app is much more community-scoped than platform-row-scoped.

### 2. Underdefined Public-Schema Contract

The plan assumes only `better_together_platforms` stays in `public`, but does not fully resolve related records that may need global visibility or careful migration treatment.

### 3. Too Little Focus On Community As The In-Schema Partition

The plan centers platform isolation but does not fully leverage the strongest existing pattern in CE: community-centered data organization. Your target architecture depends on that being explicit.

### 4. Missing Canonical Data Ownership Rules

The plan does not yet define, model by model, which records are:

- per-platform and tenant-local
- community-local inside a tenant
- personal-community-local
- global fleet metadata in `public`

### 5. Migration Complexity Is Larger Than The Plan Implies

Because the current schema contains mixed scoping patterns, migration will not be a simple "move all non-platform tables into tenant schemas" exercise. The migration strategy needs a stronger inventory and ownership map first.

---

## Recommended Direction

## Recommendation: Salvage The Existing Plan, But Replace Its Architecture Baseline

Do not discard the `feat/multi-tenant` plan entirely. It is the only dedicated artifact already oriented toward schema-per-platform tenancy, and its operational concerns are largely the right ones. However, it should not be implemented as written.

Instead:

1. Keep the schema-per-platform direction.
2. Replace the current-state section with an accurate code-backed model of the app.
3. Add a canonical ownership matrix before any implementation work begins.
4. Reframe communities as the primary in-schema partition, not a secondary detail.
5. Resolve the `public` schema contract explicitly before touching migrations.

## Minimum Architectural Decisions Needed Before Implementation

### Decision 1: `public` Schema Contract

Define which records stay global, at minimum:

- `Platform`
- domain/subdomain routing metadata
- provisioning state
- possibly support/admin fleet metadata

### Decision 2: Person Ownership Model

Choose whether `Person` is:

- tenant-local only
- global in `public` with tenant-local memberships
- or split between global identity and tenant-local profile

This is one of the most important unresolved decisions.

### Decision 3: Community Contract Inside Each Tenant

Make the following explicit:

- host community is the platform’s default community
- personal community is a first-class community type or role-backed convention
- all tenant content and operational records must resolve to a community scope unless deliberately global within the tenant

### Decision 4: Shared Definitions

Decide how roles, permissions, templates, and other shared definitions are handled:

- seeded into every tenant schema
- shared from `public`
- or versioned global definitions copied into tenants

### Decision 5: Cross-Tenant Admin Strategy

Decide how the app will support:

- support tooling
- search
- analytics
- backup oversight
- incident response

after data moves into many schemas.

---

## Suggested Follow-Up Documents

Before implementation begins, the multi-tenant effort should produce two new canonical documents:

1. `docs/implementation/multi_tenancy/tenant_data_ownership_matrix.md`
   - one row per major model or subsystem
   - explicit classification as `public-global`, `tenant-global`, `community-scoped`, `personal-community-scoped`, or `deprecated/shared`

2. `docs/implementation/multi_tenancy/tenant_runtime_contract.md`
   - request tenant resolution
   - `Current.platform` and current schema behavior
   - current community selection rules
   - background job and mailer tenant context
   - cross-tenant admin patterns

These should be completed before code implementation starts.

---

## Final Conclusion

CE already has meaningful conceptual multi-tenancy work, but it is not yet implemented as hosted-platform schema isolation.

What exists today:

- a strong community-centered domain model
- platform/community membership separation
- host-platform and host-community conventions
- one draft schema-per-tenant implementation plan

What does not yet exist:

- schema-per-platform runtime behavior
- tenant provisioning
- tenant routing
- tenant-aware jobs and mailers
- a precise public-versus-tenant data ownership contract

The repo is therefore best understood as:

**a single-schema application with community-oriented internal scoping and platform-level concepts, but without implemented tenant-schema isolation.**

That is a workable starting point for the target model you described, especially because communities already function as the main organizing boundary. The next step should not be direct implementation from PR `#1215` as-is. The next step should be revising that plan around an accurate current-state model and a canonical ownership matrix for platform, community, personal-community, and public-global data.
