# Platform Sync Sidekiq Rollout Plan

## Purpose

This document defines the production rollout plan for CE platform federation sync jobs.

The immediate goal is to isolate platform-to-platform synchronization from normal user-facing background work by:

- routing federation ingest and future sync jobs to a dedicated `platform_sync` Sidekiq queue
- running a dedicated Sidekiq worker process for that queue in production
- preserving the option to move sync work to a separate Redis backing service later if operational load justifies it

This plan assumes the current federated sync implementation direction already present in CE:

- `BetterTogether::FederatedContentIngestJob`
- `BetterTogether::Content::FederatedContentIngestService`
- `BetterTogether::PlatformConnection` sync state tracking

## Why Isolate Platform Sync Jobs

Platform sync jobs have different failure and load characteristics from ordinary CE jobs:

- they depend on remote platforms and network conditions
- they may process batches of posts, pages, and events
- they can retry during remote outages
- they can backlog when peers are slow or unavailable
- they are not directly tied to immediate user requests in the local platform

If they share the same worker pool as mailers, notifications, metrics, or default application jobs, sync traffic can reduce responsiveness for local platform operations.

The isolation objective is:

- protect user-facing queues from remote sync backlogs
- scale sync workers independently
- observe sync behavior separately
- make federation failures operationally visible without degrading the rest of the app

## Recommended Production Topology

### Phase 1: Dedicated Queue, Shared Redis

This is the minimum production baseline and should be the first rollout step.

- queue name: `platform_sync`
- Sidekiq worker process:
  - existing worker continues consuming `default`, `mailers`, `notifications`, `metrics`, `maintenance`, `es_indexing`, `geocoding`
  - new worker consumes only `platform_sync`
- Redis:
  - shared with the rest of Sidekiq
  - same Redis instance/URL as current CE job processing

This gives process isolation without introducing new Redis operational complexity.

### Phase 2: Dedicated Queue, Dedicated Sidekiq Process Per Production App

This should be the normal steady-state production setup for CE apps that enable federation.

For each production CE app:

- `web`
- `sidekiq-default`
- `sidekiq-platform-sync`

Expected behavior:

- normal app jobs remain responsive even if peer sync is slow
- `platform_sync` concurrency can be tuned separately per app
- sync workers can be restarted or scaled without touching default queues

### Phase 3: Optional Dedicated Redis Backing For Sync

Do not make this the initial requirement.

Move to a separate Redis DB or instance only if one or more of these becomes true:

- `platform_sync` queue depth regularly interferes with normal queues
- large sync batches or retry storms create Redis memory or latency pressure
- multiple CE apps on the same host all run heavy federation traffic
- operators need stronger isolation for incident response

If Phase 3 is adopted:

- keep the queue name `platform_sync`
- introduce a dedicated env var such as `REDIS_PLATFORM_SYNC_URL`
- bind the `sidekiq-platform-sync` process to that Redis target only

## Queue And Process Design

### Canonical Queue Names

- `default`
- `mailers`
- `notifications`
- `metrics`
- `maintenance`
- `es_indexing`
- `geocoding`
- `platform_sync`

Future federation-specific jobs should also use `platform_sync`, for example:

- remote batch pull jobs
- mirror refresh jobs
- publish-back jobs
- remote connection health checks
- sync reconciliation or replay jobs

### Process Split

Recommended process split:

- `sidekiq-default`
  - queues: `default`, `mailers`, `notifications`, `metrics`, `maintenance`, `es_indexing`, `geocoding`
- `sidekiq-platform-sync`
  - queues: `platform_sync`

Do not run the sync queue on the default worker once dedicated sync workers are live, except as an intentional temporary fallback during rollout.

## Environment And Config Changes

### Application-Level

The application code should:

- keep `BetterTogether::FederatedContentIngestJob` on `queue_as :platform_sync`
- route future sync jobs to the same queue by default
- keep sync state on `PlatformConnection` for visibility

### Sidekiq Config

Each production deployment should provide a Sidekiq config that includes `platform_sync`.

The worker definitions should explicitly subscribe to the intended queue sets, rather than relying on one generic Sidekiq worker for all queues.

### Redis

Initial production env:

- `REDIS_URL` for normal app and Sidekiq traffic

Optional later env:

- `REDIS_PLATFORM_SYNC_URL` for dedicated sync workers

## Rollout Sequence

### Step 1: Land Queue Routing In Code

- merge code that sets federation ingest and future sync jobs to `platform_sync`
- confirm test Sidekiq config includes `platform_sync`
- verify job specs cover queue selection

### Step 2: Deploy Without Dedicated Sync Worker Yet

Short transitional step only.

- deploy the code
- allow current Sidekiq worker to see `platform_sync`
- verify no immediate enqueue/runtime regressions

This step should be brief because isolation is not complete until the dedicated worker exists.

### Step 3: Add Dedicated `sidekiq-platform-sync` Process

Per production app/server configuration:

- add a new Sidekiq process for `platform_sync`
- keep the existing worker for non-sync queues
- start the new worker with bounded concurrency

Suggested initial sync concurrency:

- start at `1` or `2` per app
- increase only after observing queue depth, runtime, and remote-peer behavior

### Step 4: Remove `platform_sync` From Default Worker

Once the dedicated sync worker is stable:

- remove `platform_sync` from the default worker queue list
- ensure all federation sync jobs still drain correctly

This is the point where real isolation begins.

### Step 5: Evaluate Redis Separation

After at least one observation window in production:

- review queue depth
- review retry volume
- review memory and latency on Redis
- decide whether `REDIS_PLATFORM_SYNC_URL` is justified

## Monitoring And Alerting

Monitor `platform_sync` separately from the default job pool.

Minimum metrics:

- queue depth for `platform_sync`
- average and p95 job runtime
- retry count
- dead job count
- time since last successful sync per `PlatformConnection`
- count of failed `PlatformConnection` sync states

Minimum UI/ops visibility:

- Sidekiq queue dashboard shows `platform_sync`
- `PlatformConnection` show page displays:
  - sync status
  - last sync started
  - last sync completed
  - last sync item count
  - sync cursor
  - last error

Suggested alerts:

- `platform_sync` queue depth above threshold for sustained interval
- repeated failures for the same connection
- no successful sync for active connections beyond expected window
- dead jobs in `platform_sync`

## Failure Handling Expectations

The sync queue must be treated as externally-coupled work.

Operational rules:

- remote peer failure should not block default queues
- retries should stay inside `platform_sync`
- connection-level failure state should be visible on `PlatformConnection`
- operators must be able to pause or suspend a `PlatformConnection` without affecting unrelated jobs

## Capacity Guidance

Start conservative.

Initial recommendation per production CE app:

- default worker concurrency sized for normal app workload
- sync worker concurrency `1-2`

Increase sync concurrency only when:

- queue depth is sustained
- remote peers can tolerate parallel pulls
- Redis and DB load stay acceptable

Do not scale sync workers solely to eliminate backlog if the real issue is a failing or slow peer.

## Risks

### If `platform_sync` Shares The Default Worker Forever

- remote outages can starve local job processing
- retries can crowd out mailers and notifications
- operational visibility remains blurred

### If Separate Redis Is Adopted Too Early

- more env/config complexity
- more operational overhead
- harder local parity and debugging

The recommended path is queue isolation first, Redis isolation later if needed.

## Acceptance Criteria

This rollout is complete when:

- federation ingest jobs enqueue on `platform_sync`
- production Sidekiq shows a dedicated `platform_sync` worker process
- default workers no longer consume `platform_sync`
- sync failures do not interfere with mailers, notifications, or default jobs
- operators can observe per-connection sync status from CE and per-queue status from Sidekiq

## Follow-On Work

After this rollout plan is approved, the next implementation work should cover:

- a federation pull endpoint or client that feeds `FederatedContentIngestJob`
- scheduled sync jobs on `platform_sync`
- optional `REDIS_PLATFORM_SYNC_URL` support in production deployment config
- queue-specific deployment documentation for Dokku and BTS server topology
