# Federated Seed And Sync Handoff

Date: 2026-03-12
Branch: `agent/codex/019cdef3-03bf-7153-b45c-e36f8a1ad56c-ce-mt`
PR draft URL: `https://github.com/better-together-org/community-engine-rails/pull/new/agent/codex/019cdef3-03bf-7153-b45c-e36f8a1ad56c-ce-mt`

## Purpose

This document is a compact export summary of the current CE federation, multi-tenancy, stewardship/RBAC, and seed-based sync work so a later agent session can resume without re-deriving the architecture or implementation status.

The current direction combines:

- schema-per-platform multi-tenancy
- communities as the in-schema organizing boundary
- platform-to-platform federation
- person-to-person linked access grants
- seed / planting / tending terminology for CE-native import-export

## Canonical Planning Stack

The current planning baseline is spread across these documents:

- `docs/implementation/multi_tenancy/tenant_data_ownership_matrix.md`
- `docs/implementation/multi_tenancy/tenant_runtime_contract.md`
- `docs/implementation/multi_tenancy/schema_per_tenant_implementation_plan.md`
- `docs/implementation/multi_tenancy/governance_bodies_and_mandates.md`
- `docs/implementation/multi_tenancy/federated_rbac_reassessment_and_coverage_plan.md`
- `docs/implementation/multi_tenancy/rbac_role_permission_matrix.md`
- `docs/implementation/multi_tenancy/rbac_policy_coverage_matrix.md`
- `docs/implementation/multi_tenancy/rbac_identifier_migration_plan.md`
- `docs/production/platform_sync_sidekiq_rollout_plan.md`

Conceptual language should remain human-centered:

- `Seed`: the portable CE unit of structure, content, or relationship data
- `Planting`: importing or applying seeds into a platform
- `Tending`: ongoing refresh and synchronization of planted seeds

## Architecture Summary

### Multi-tenancy

- Target model remains schema-per-platform.
- Communities remain the primary in-schema partition and governance structure.
- Platform routing is now anchored in `Platform` plus `PlatformDomain`.

### Governance and RBAC

- Platform stewardship and community governance remain distinct.
- `platform_steward` is the canonical successor to `platform_manager`.
- `community_governance_council` remains distinct from `community_organizer`.
- Network/federation authority has been split away from generic platform management.

### Federation

- `PlatformConnection` is the durable platform-to-platform relationship edge.
- `Joatu::ConnectionRequest` is the negotiation flow for creating platform connections.
- Platform sync is asynchronous and uses the dedicated `platform_sync` Sidekiq queue.
- The current bearer-token feed auth is temporary scaffolding. The intended target remains CE-to-CE OAuth.

### Seeds, Plantings, and Tending

- The old `the-seed` concepts have been revived as the canonical CE package layer.
- `Seed` is the portable envelope.
- `SeedPlanting` tracks imports/applications.
- `Seedable` is the model-level export contract.
- Manual import/export, scheduled sync, and private linked sync should share the seed schema while remaining separate processes.

### Person-linked private sharing

- Platform-to-platform sharing and person-to-person linked sharing are separate lanes.
- `PersonLink` models a durable cross-platform person relationship.
- `PersonAccessGrant` models recipient-specific private access scopes.
- `PersonLinkedSeed` is the recipient-scoped cached private seed lane.
- Private linked payloads are encrypted at rest with Active Record encryption.
- Private linked content must not surface in general network feeds, public/community listings, or generic search.

## Completed Implementation Slices

### 1. Stewardship / RBAC transition

Implemented earlier on this branch:

- canonical `platform_steward`, `analytics_viewer`, `community_organizer` compatibility wave
- narrowed membership, invitation, Joatu, platform, role, resource-permission, and content policies
- dedicated network permissions layered on top of stewardship roles

This work is checkpointed in earlier commits leading up to the federation slices.

### 2. Platform routing and registry

Implemented:

- `PlatformDomain`
- host/canonical domain routing
- platform registry semantics on `Platform`
- local vs external peer platform helpers

Key commits:

- `2e1265b9` platform domain routing slice
- `6cab131e` platform registry semantics

### 3. Platform connections and connection requests

Implemented:

- `PlatformConnection`
- active incoming/outgoing platform associations
- `Joatu::ConnectionRequest`
- acceptance flow that creates or activates `PlatformConnection`
- explicit network authorization layer for request/agreement handling
- initial `PlatformConnectionsController` management UI

Key commits:

- `c7dcb007`
- `f02cdfe4`
- `d3ed2c60`
- `d4d86d11`
- `842d4a79`
- `5c1c7d5c`

### 4. Platform connection policy settings and sync state

Implemented on `PlatformConnection.settings`:

- content sharing policy
- federation auth policy
- content type toggles
- auth scope toggles
- sync state tracking:
  - cursor
  - last sync status
  - start/completion/error timestamps
  - item counts

Key commits:

- `b63bb2cb`
- `2ef1ff1f`

### 5. Federation authorization primitives

Implemented:

- `FederationScopeAuthorizer`
- `FederatedContentAuthorizer`

These are the current reusable gates for scope grants and content mirroring rules.

Key commit:

- `c8eccf89`

### 6. Mirrored content provenance and import

Implemented for:

- `Post`
- `Page`
- `Event`

Added provenance and sync fields:

- `platform_id`
- `source_id`
- `source_updated_at`
- `last_synced_at`

Implemented services:

- `FederatedPostMirrorService`
- `FederatedPageMirrorService`
- `FederatedEventMirrorService`

Behavior:

- preserves remote UUIDs for CE UUID-compatible sources
- falls back to local UUID plus `source_id` for non-CE or non-UUID sources
- idempotent upsert semantics

Key commits:

- `416d2e00`
- `7f8a8534`
- `69491957`

### 7. Async platform content feed / pull / ingest

Implemented:

- federated content feed endpoint
- pull service
- ingest service
- ingest job
- pull job
- sync scan job
- `platform_sync` queue wiring
- hourly scheduler entry

Key commits:

- `70a2eb16`
- `4e638bd2`
- `64b1d7ce`
- `b0ba6526`

### 8. Seed federation integration

Implemented:

- `BetterTogether::Seed`
- `BetterTogether::SeedPlanting`
- `BetterTogether::Seedable`
- seed builder and ingestor services
- content export/import/pull flows adapted to seed-based exchange

Key commit:

- `1fa53eee`

### 9. Person links and access grants

Implemented:

- `PersonLink`
- `PersonAccessGrant`
- `Joatu::PersonLinkRequest`
- `Joatu::PersonAccessGrantRequest`
- agreement compatibility logic for these request/offer types

Behavior:

- accepted Joatu flows materialize or activate durable links/grants
- access grants are conservative and fail closed by default

Key commit:

- `4c07590a`

### 10. Private linked seed lane

Implemented:

- `PersonLinkedSeed`
- `PersonLinkedSeedCacheService`
- encrypted private payload at rest
- recipient-only visibility logic tied to active grants

Key commit:

- `71f923b7`

## Current Completion Status

### Substantially complete foundations

- stewardship and RBAC planning/doc stack
- first RBAC implementation wave
- platform registry and routing
- platform connection primitives
- async platform sync queueing and state tracking
- shared content mirroring for posts, pages, events
- seed/planting/tending core model layer
- person-link and access-grant data model
- private linked-seed encrypted cache lane

### Partially complete / transitional

- federation feed auth still uses a temporary bearer-token path in places
- CE-to-CE OAuth remains planned but not yet wired end-to-end
- seed-based exchange is integrated, but not yet fully generalized into all federation endpoints and workflows
- person-linked private sync storage exists, but a full export/import API flow for linked private seeds is not implemented yet

### Not yet complete

- CE-to-CE OAuth token issuance and validation path for federation transport
- private linked-seed export endpoint and pull/ingest flow
- grant management UI for updating, revoking, and expiring person access grants
- complete non-leakage audit across all feed/search/listing surfaces
- eventual migration from temporary bearer-token sync auth to OAuth-only federation auth

## Important Operational Notes

### Migration path

Use the CE repo root as the authoritative migration path.

Use:

- `bin/dc-run bundle exec rails db:migrate`
- `RAILS_ENV=test bin/dc-run bundle exec rails db:migrate`

Do not rely on direct dummy-app migrations as the authoritative path.

The engine harness handles the migration wiring. Earlier confusion around missing migration paths was caused by dummy-migration duplication and non-authoritative invocation paths.

### Test harness notes

- `db:migrate` from the repo root works reliably.
- `rails db:prepare` is not consistently exposed from the repo root in this engine shell.
- `rails runner` from the repo root is also not reliable here because `Rails.application` is nil in that execution path.
- Focused Docker-backed specs have been used as the main verification path.

### Sidekiq / queueing

- `platform_sync` is the dedicated queue for platform sync work.
- A production rollout plan exists at `docs/production/platform_sync_sidekiq_rollout_plan.md`.
- The recommended production shape is a dedicated Sidekiq worker/process for `platform_sync`, with the option to split Redis later if load warrants it.

## Branch And Git Status At Export Time

- Branch: `agent/codex/019cdef3-03bf-7153-b45c-e36f8a1ad56c-ce-mt`
- GitHub branch exists and has been pushed regularly.
- PR draft URL:
  - `https://github.com/better-together-org/community-engine-rails/pull/new/agent/codex/019cdef3-03bf-7153-b45c-e36f8a1ad56c-ce-mt`
- At the time this summary was prepared, the branch was one commit ahead of the GitHub remote and otherwise clean aside from untracked log directories.

## Immediate Next Steps

### 1. Replace temporary federation bearer-token auth with CE-to-CE OAuth

Do next:

- establish CE-to-CE OAuth app/client relationship per active `PlatformConnection`
- issue scoped access tokens based on `FederationScopeAuthorizer`
- move feed and tending endpoints to OAuth-backed auth
- deprecate `PlatformConnection#federation_access_token`

### 2. Build the private linked-seed tending flow

Do next:

- add linked private-seed export endpoint or service lane
- gate it on:
  - active `PlatformConnection`
  - active `PersonLink`
  - active `PersonAccessGrant`
  - private linked-content scopes
- add pull + ingest flow on `platform_sync`
- keep imported records recipient-scoped only

### 3. Complete non-leakage policy and query review

Do next:

- confirm `PersonLinkedSeed` and later linked-private projections do not appear in:
  - network feed
  - community feeds
  - search
  - general platform content queries
- make any missing policy/query boundaries explicit and tested

### 4. Add grant lifecycle management

Do next:

- editing scopes
- revocation
- expiry handling
- auditability for agreement acceptance and grant changes

### 5. Continue seed-layer generalization

Do next:

- ensure all CE federation export/import endpoints exchange seeds consistently
- keep manual planting and automated tending separate processes while sharing the seed schema

## Suggested Resume Point For A New Agent Session

Resume from this order:

1. confirm branch status and push this summary if not already pushed
2. implement CE-to-CE OAuth for federation transport
3. add private linked-seed export/pull/ingest flow
4. run focused specs for the new OAuth + linked-private path
5. update this handoff doc with the new completion state
