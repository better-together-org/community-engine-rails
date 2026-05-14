# Storage Configuration Guide

**Target Audience:** Platform organizers  
**Document Type:** Operator guide  
**Last Updated:** March 2026

This guide explains the platform-scoped storage configuration system introduced in the `0.11.0` release lane.

## What changed in 0.11.0

Platforms can now define storage backends through `StorageConfiguration` records instead of relying only on environment-wide Active Storage settings.

Supported service types:

- `local`
- `amazon`
- `s3_compatible`

Examples of S3-compatible backends include Garage and MinIO.

## Core behavior

### Platform-owned configurations

A platform can own many storage configurations, but only one active configuration at a time.

Relevant model relationships:

- `Platform has_many :storage_configurations`
- `Platform belongs_to :active_storage_configuration`

### Resolution order

`BetterTogether::StorageResolver` uses this order:

1. active platform storage configuration
2. environment-based Active Storage settings
3. local disk fallback

This means you can adopt platform-scoped storage incrementally without breaking existing deployments that still rely on environment variables.

## Managing configurations

The storage configuration UI is nested under the platform:

- list configurations
- create a configuration
- edit a configuration
- activate a configuration
- delete an inactive configuration

When activating a configuration, the controller immediately rebinds the Active Storage service in the current process so new uploads use the updated backend without waiting for a restart. Other processes still need their normal restart cycle.

## Choosing a backend

### Local disk

Use local disk when:

- you are in development
- you are running a simple single-host deployment
- you do not need remote object storage

### Amazon S3

Use Amazon S3 when:

- you want a managed object store
- you need mature ecosystem support
- your deployment and compliance model already assume AWS

### S3-compatible storage

Use an S3-compatible backend when:

- you want self-hosted object storage
- you are standardizing on Garage or MinIO
- you need a private object store with the Active Storage S3 adapter path

For S3-compatible backends, an explicit endpoint is required and the system enables `force_path_style`.

## Credentials and safety

`StorageConfiguration` encrypts the following fields at rest:

- `access_key_id`
- `secret_access_key`

When editing an existing configuration, blank credential fields are stripped from the update payload so existing encrypted values are preserved.

## Activation workflow

Recommended activation sequence:

1. create the configuration for the target platform
2. verify bucket, region, and endpoint settings
3. activate the configuration
4. perform a small upload test
5. restart other long-lived processes on the deployment if needed

Do not destroy the currently active configuration. The controller blocks that path intentionally.

## Operator caveats

### Platform config vs environment fallback

If no active platform config exists, `StorageResolver` will still use environment variables. This is useful during migration, but it also means operators should verify which source is currently active before assuming a UI change is taking effect.

### Stable storage keys

Each `StorageConfiguration` produces a stable key based on the config record ID. This prevents an unrelated config swap from silently redirecting old blobs to a different backend identity.

### Process rebinding

Immediate rebinding only affects the current process. Background workers and other app processes should still be restarted or recycled through the normal deployment path.

## Related docs

- [Multi-tenant platform runtime](../developers/systems/multi_tenant_platform_runtime.md)
- [0.11.0 Release Overview](../releases/0.11.0.md)

## Diagram

- [Storage backend selection flow](../diagrams/source/storage_backend_selection_flow.mmd)
