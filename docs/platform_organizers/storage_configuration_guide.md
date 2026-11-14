# Storage Configuration Guide

<!-- doc-coverage: better_together/storage_configurations -->

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

## Using Garage (solo host app)

A host app that runs one platform can use a self-hosted Garage bucket today, with environment variables only:

| Variable | Value |
| --- | --- |
| `ACTIVE_STORAGE_SERVICE` | `s3_compatible` |
| `S3_ENDPOINT` | the Garage S3 endpoint, for example `https://s3.example.org` (or `http://garage:3900` on the same Docker network) |
| `S3_REGION` | any non-empty string, by convention `garage` |
| `S3_BUCKET_NAME` | the bucket for this app |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | the key pair granted on that bucket |
| `AWS_REQUEST_CHECKSUM_CALCULATION`, `AWS_RESPONSE_CHECKSUM_VALIDATION` | `when_required` for both |
| `ACTIVE_STORAGE_ROUTE` | `proxy`, so the app serves files and no public bucket read is needed |

Notes that save time:

- The host app's `config/storage.yml` needs an `s3_compatible` service with `force_path_style: true`. Copy the one from this repository's dummy app.
- Garage signs with SigV4 only and has no IAM or bucket policy. Access is per key per bucket, so give each app its own key and grant it read, write and owner on its own bucket only.
- Garage cannot set CORS with a normal app key. Set the bucket CORS rule once with the owner key, with your site origins and the methods GET, PUT, POST and HEAD, before using direct uploads.
- Add the storage origin (the endpoint host) to the Content Security Policy image and connect sources. Use `BetterTogether.register_content_security_policy_sources` from a host initializer.
- Garage has no per-bucket data directory, so back up through an S3 reader that has read access to the bucket, not by copying the data directory.
- Run a small upload, download and delete round trip against the bucket before switching traffic.

## Hosted platforms (design, not yet implemented)

Today the Active Storage service is process-wide and bound at boot from the host platform. A platform that
is not the host can save a `StorageConfiguration`, but its uploads still land in the host's bucket.
Per-platform buckets are planned in these steps:

1. A service router resolves the storage service from the current platform and stamps it on each new blob, so every blob remembers its own service.
2. `StorageConfiguration` gains a connection test, a health state, key rotation and a rule that a bucket belongs to one platform only.
3. The platform form gets a Storage tab with a test connection button.
4. The media gate, direct uploads, variants, seed packet imports and quota accounting follow the blob's platform service.
5. Platform export and deletion include the platform's blobs.

Until step 1 ships, a hosted platform must not be given a separate bucket and must not be told its files are isolated. See [storage requirements for tier 3 tenancy](../implementation/multi_tenancy/storage_requirements.md).

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
