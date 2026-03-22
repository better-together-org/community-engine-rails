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
- CE-to-CE OAuth-style token issuance is now partially implemented for platform-shared feed transport.
- The legacy long-lived bearer token still exists as a transition fallback and should be removed after the OAuth path is fully adopted.

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

### 11. OAuth-style federation token exchange

Implemented:

- connection-bound OAuth client credentials on `PlatformConnection`
- short-lived scoped `FederationAccessToken`
- `FederationAccessTokenIssuer`
- `POST /:locale/.../federation/oauth/token`
- feed export auth updated to accept scoped access tokens
- pull service updated to obtain a short-lived access token before requesting the shared content feed
- new `linked_content.read` scope added to the authorization model for the account-to-account lane, defaulting off

Behavior:

- current implementation is a bounded CE client-credentials flow over existing platform connections
- shared content feed tending now prefers short-lived scoped access tokens
- legacy `federation_access_token` remains as transition fallback for feed reads and pulls
- private linked-content transport is not implemented yet, but the scope vocabulary now reserves `linked_content.read`

### 12. Private linked-seed transport

Implemented:

- linked-private seed export service
- linked-private feed endpoint
- linked-private pull service
- linked-private ingest service
- linked-private pull job on `platform_sync`
- linked-private sync scan job on `platform_sync`
- immediate soft-hide lifecycle semantics for revoked or expired grants

Files added in this slice include:

- `app/services/better_together/seeds/linked_seed_export_service.rb`
- `app/services/better_together/seeds/linked_seed_ingest_service.rb`
- `app/services/better_together/federated_linked_seed_pull_service.rb`
- `app/jobs/better_together/federated_linked_seed_pull_job.rb`
- `app/controllers/better_together/federation/linked_seeds_controller.rb`

Behavior:

- exports only grantor-authored private `Post` / `Page` / `Event` records allowed by an active `PersonAccessGrant`
- requires `linked_content.read`
- requires recipient identifier targeting
- imports into `PersonLinkedSeed` through `PersonLinkedSeedCacheService`
- does not route private linked content through the shared platform mirror tables
- can now be orchestrated through a scan job that enqueues recipient-scoped pulls only for active grants on linked-content-enabled connections
- revoked or expired grants immediately stop visibility, export eligibility, scan eligibility, and queued pull execution
- cached linked-private seeds are soft-hidden by grant state rather than deleted automatically

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
- first private linked-seed transport path

### Partially complete / transitional

- platform-shared feed auth now supports scoped token exchange, but the OAuth path is still transitional rather than a full provider implementation
- federation feed auth still includes the old long-lived bearer-token fallback
- seed-based exchange is integrated, but not yet fully generalized into all federation endpoints and workflows
- linked-private seed export/pull/ingest exists, but scheduling, lifecycle controls, and broader recipient-content coverage are still incomplete
- linked-private scan scheduling and immediate soft-hide revocation behavior exist, but destructive cleanup and more advanced cadence controls are still incomplete

### Not yet complete

- full CE-to-CE OAuth provider/client lifecycle beyond the current bounded client-credentials transport
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

- extend the current bounded token exchange into the remaining federation surfaces
- remove legacy bearer-token fallback after the new path is used everywhere
- decide whether to keep the current lightweight CE provider path or replace it with a fuller provider stack
- add linked private-content token flow on top of the same scope model

### 2. Build the private linked-seed tending flow

Do next:

- extend the current linked-private path beyond the first bounded transport lane
- decide how linked-private pulls should be scheduled or user-triggered
- expand beyond grantor-authored private `Post` / `Page` / `Event` records if needed
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
