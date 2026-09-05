# Federation Setup and Activation

**Target Audience:** Platform organizers  
**Document Type:** Operator guide  
**Last Updated:** March 2026

This guide explains how to activate and operate platform-to-platform federation in the `0.11.0` release lane.

## What federation enables

Federation lets your platform establish a durable trust relationship with another platform and then:

- authorize machine access for content feed exchange
- mirror selected posts, pages, and events
- track sync state per connection
- isolate sync jobs from ordinary user-facing background work

## Before you begin

Confirm the following first:

- the `0.11.0` platform and federation migrations are deployed
- the host platform exists and resolves correctly for the public host name
- Sidekiq is running with the `platform_sync` queue available
- the peer platform has a stable public base URL
- you have reviewed the governance and privacy implications of sharing content with that platform

See also:

- [Multi-Tenancy Upgrade Guide](../upgrade/multi-tenancy-upgrade.md)
- [Platform Sync Sidekiq Rollout Plan](../production/platform_sync_sidekiq_rollout_plan.md)

## Step 1: create the platform records

Federation depends on valid platform records for both sides of the relationship.

Verify:

- your local host platform is marked `host: true`
- the remote platform exists as a non-host platform record with the correct host URL and issuer details

## Step 2: create the `PlatformConnection`

Use the platform connections interface to create a new connection between:

- the local source platform
- the target or peer platform

Choose the correct connection kind:

- `peer` for platform-to-platform federation
- `member` only when the relationship model truly reflects that policy

New connections begin in a controlled state and should be reviewed before activation.

## Step 3: configure sharing and authorization policy

Review the connection settings carefully.

Important controls include:

- content-sharing enabled or disabled
- sharing policy
- content-type toggles for posts, pages, and events
- OAuth/federation auth policy
- per-scope allow flags such as identity and content read

Only grant the scopes your federation relationship actually needs.

## Step 4: activate the connection

Approve the connection only after both sides are configured as intended.

Connection status moves through states such as:

- `pending`
- `active`
- `suspended`
- `blocked`

Use `suspended` when you need to pause federation without deleting the relationship.

## Step 5: verify token issuance and feed access

At minimum, verify:

- the federation OAuth token endpoint responds as expected
- the remote platform can obtain a scoped bearer token
- the content feed endpoint returns seeds for an authorized token

If token issuance fails, check:

- the resolved `Current.platform`
- the connection status
- the OAuth client ID and client secret
- whether the requested scopes are actually allowed

## Step 6: monitor sync behavior

Once federation is active, monitor the connection directly.

Key fields and behaviors to watch:

- last sync status
- last sync started and completed timestamps
- last sync item count
- sync cursor progression
- last sync error message

Because sync jobs run on `platform_sync`, you should also monitor that queue separately from ordinary mailer, notification, and default jobs.

## Operational guidance

### When to suspend a connection

Suspend instead of deleting when:

- a peer is misconfigured
- a remote outage is causing retry churn
- governance approval is being revisited
- you need to pause data exchange during incident response

### What federation does not do

Federation does not merge governance or moderation domains automatically. Mirrored content still lands inside your local platform context and should be governed by your local platform’s stewardship and moderation practices.

### Shared-database caution

When the target is local-hosted in the same database, the mirror layer avoids blindly preserving remote UUIDs. This is intentional and protects against collisions.

## Related docs

- [Federation system](../developers/systems/federation_system.md)
- [Multi-tenant platform runtime](../developers/systems/multi_tenant_platform_runtime.md)
- [Platform Sync Sidekiq Rollout Plan](../production/platform_sync_sidekiq_rollout_plan.md)

## Diagrams

- [Platform connection flow](../diagrams/source/federation_platform_connection_flow.mmd)
- [OAuth trust flow](../diagrams/source/federation_oauth_trust_flow.mmd)
- [Content mirroring flow](../diagrams/source/federation_content_mirroring_flow.mmd)
