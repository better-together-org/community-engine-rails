# Storage requirements for tier 3 tenancy

**Document Type:** Requirements
**Status:** Draft, written ahead of the storage chunks (service router, hardening, form tab)

This is the storage part of the Phase 3 "tenant infrastructure" list in the staged tenancy approach.
Link it from the Phase 3 section of `staged_tenancy_approach.md` once that file is on `main`.

## Current state

- One process-wide Active Storage service, bound at boot from the host platform's `StorageConfiguration` (`config/initializers/storage.rb`).
- `StorageResolver#register!` exists and is unused. It is the seam for per-platform services.
- Blob keys are random and carry no platform prefix, and blobs have no platform column. The only real boundary between two platforms is a separate bucket.
- The media gate checks the attached record's policy and has no platform check on the blob.
- Quotas are platform-dimensioned in the database but are not tied to a bucket.

## Requirements

1. **Per-platform service.** A blob created while `Current.platform` is set is stamped with that platform's service name. Reads, variants and purges use the blob's own `service_name`, never the process default.
2. **Isolation by bucket.** Two platforms never share a bucket. A bucket is unique across `StorageConfiguration` rows, and a second platform using the same bucket and endpoint is rejected.
3. **Fail closed.** If a platform's service cannot be built or fails its health check, uploads for that platform fail with a clear error. They never fall back to the host bucket.
4. **Credentials.** Keys stay encrypted at rest, are never shown after save, can be rotated without a restart, and are never logged.
5. **Endpoint safety.** A tenant-supplied endpoint passes the same outbound host check used for other tenant URLs, so it cannot point at internal addresses.
6. **Media gate.** The gate compares the blob's platform service with the viewing platform and denies a mismatch. Mirrored or federated content is served through a defined policy, not a shared blob escape.
7. **Direct uploads and variants.** Presigned URLs are issued against the platform's endpoint and bucket, and variants are written to the original blob's service.
8. **Seeds.** Importing a seed packet writes blobs to the target platform's service.
9. **Quotas.** Storage accounting counts the platform's own blobs and ties to its billing allowance.
10. **Lifecycle.** Exporting or deleting a platform covers its blobs, and deletion removes them from the platform's bucket or hands the bucket back to its owner.
11. **Operations.** Each bucket has a quarantine bucket, an antivirus reader and a backup reader, provisioned outside the app. The app only needs the platform's key.
12. **Proof.** A two-platform spec covers blobs, variants and direct uploads, and a live round trip check runs against each real bucket before a platform goes live.

## Out of scope

Key prefixes inside a shared bucket. Prefixes are not a security boundary here.
