# Multi-Tenant Platform Runtime

This document explains the runtime platform model used in the `0.11.0` release lane. In Community Engine, “multi-tenant” currently means host-and-platform-aware request scoping and platform-bound records inside a shared application, not a fully separate schema per tenant.

## Runtime model at a glance

The current runtime model is built around:

- a host platform record
- `PlatformDomain` resolution from the incoming request host
- `Current.platform` and `Current.platform_domain`
- platform-bound content and memberships
- explicit `PlatformConnection` records for inter-platform federation

This is the runtime model operators and developers work with today.

## What this release adds

The `0.11.0` release lane introduces the main platform-level building blocks:

- `better_together_platforms`
- `better_together_person_platform_memberships`
- `better_together_platform_connections`
- `better_together_federation_access_tokens`
- `platform_id` on posts, pages, events, and notifications

These changes give the application a platform-aware runtime boundary even though data still lives in the same Rails application and primary database.

## Context resolution

### `Current`

Location: `app/models/current.rb`

`Current` stores:

- `person`
- `platform`
- `platform_domain`

This keeps platform resolution available throughout request handling, mailers, jobs, and helpers.

### Rack middleware

Location: `app/middleware/better_together/platform_context_middleware.rb`

The middleware resolves the request host before controller actions run:

1. get the hostname from the rack request
2. resolve the matching `PlatformDomain`
3. choose the domain’s platform, or fall back to the cached host platform
4. assign `Current.platform_domain` and `Current.platform`
5. reset `Current` and `ActiveStorage::Current` after the request

This is the main reason platform-aware behavior is available consistently across:

- web requests
- JSON:API controllers
- federation API controllers
- MCP/tooling paths

## Host platform fallback

If the request does not resolve to a known `PlatformDomain`, the middleware falls back to the host platform. The host platform ID is cached rather than serializing a full Active Record object into the cache store, which avoids stale-object and YAML safe-load problems.

## Platform-bound records

Several release surfaces are now explicitly platform-bound:

- posts
- pages
- events
- notifications
- platform memberships
- storage configurations

This keeps local queries and federation behaviors anchored to the active platform context.

## Federation inside the platform runtime

Federation is not a separate subsystem floating outside the tenant model. It is built directly on top of the platform runtime:

- `PlatformConnection` links two platforms
- federation OAuth trust uses the resolved source platform
- mirrored content is imported into the target platform
- sync state is stored on the connection itself

That means multi-tenant runtime and federation docs should be read together.

## Storage in the platform runtime

Storage configuration is also platform-aware in this release:

- a platform can own many `StorageConfiguration` records
- a platform can select one active storage configuration
- `StorageResolver` falls back to environment configuration if no platform config is active

This is one of the first operator-facing examples of a platform-level runtime decision that changes infrastructure behavior without requiring a separate application instance.

## Operational expectations

For an upgraded deployment, operators should expect:

- one host platform exists
- existing content records are backfilled to the host platform
- existing people gain host-platform memberships
- platform-aware routes and federation endpoints are mounted after migration

The deployment and migration sequence is documented in the upgrade guide.

## What this is not

This document is intentionally about the runtime model in the current release lane. It does **not** claim that Community Engine has completed schema-isolated tenant separation.

For future or broader architecture planning, continue to treat:

- `docs/implementation/multi_tenancy/*`
- `docs/assessments/multi_tenancy_gap_assessment_2026-03-11.md`

as planning and assessment artifacts rather than the canonical “how it works today” runtime source.

## Related docs

- [Federation system](federation_system.md)
- [Multi-Tenancy Upgrade Guide](../../upgrade/multi-tenancy-upgrade.md)
- [Storage configuration guide](../../platform_organizers/storage_configuration_guide.md)
- [0.11.0 Release Overview](../../releases/0.11.0.md)

## Diagram

- [Multi-tenant platform runtime flow](../../diagrams/source/multi_tenant_platform_runtime_flow.mmd)
