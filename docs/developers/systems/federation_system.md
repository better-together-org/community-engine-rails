# Federation System

**Target Audience:** Developers and maintainers  
**Document Type:** System documentation  
**Last Updated:** July 19, 2026

## Overview

The federation system models a directed trust relationship between two platforms using `BetterTogether::PlatformConnection`.

Current responsibilities include:

- storing connection state and policy
- issuing connection-bound OAuth-style access tokens
- authorizing connection scopes
- authorizing mirrored content types
- tracking sync state
- orchestrating pull-based content mirroring

## Core Model: `PlatformConnection`

`BetterTogether::PlatformConnection` is the durable edge between a source platform and a target platform.

Key state:

- `status`: `pending`, `active`, `suspended`, `blocked`
- `connection_kind`: `peer`, `member`
- `content_sharing_policy`
- `federation_auth_policy`
- sharing toggles for posts, pages, and events
- scope toggles for identity, profile read, content read, linked content read, and content write
- sync status fields such as cursor, timestamps, error message, and item count

Important implementation detail:

- `PlatformConnectionFederationPolicy` normalizes the settings before validation
- `content_sharing_enabled` and `federation_auth_enabled` are derived from the chosen policy values
- when policy is `none`, related booleans are reset to `false`

## Directed Trust

Federation authorization is directional.

- token issuance looks up an **active** connection where `source_platform == Current.platform`
- scope authorization looks up an **active** connection matching the requested source and target
- mirrored content decisions are evaluated against the connection used for that direction

This means a bidirectional relationship requires two explicit directed permissions in practice, even if the user experience frames it as one relationship.

## Scope Authorization

`BetterTogether::FederationScopeAuthorizer` maps requested scopes to connection settings.

Currently supported scopes are:

- `identity.read`
- `person.profile.read`
- `content.read`
- `content.feed.read`
- `linked_content.read`
- `content.mirror.write`
- `content.publish.write`

The authorizer returns granted, denied, and unsupported scopes. Unsupported or denied scopes fail closed.

## Content Authorization

`BetterTogether::Content::FederatedContentAuthorizer` decides whether a connection may mirror or publish back a content type.

Current supported content types are:

- posts
- pages
- events

For mirroring to be allowed:

- the connection must be active
- mirrored content must be enabled by policy
- the specific content type must be enabled

For publish-back to be allowed:

- the connection must be active
- publish-back policy must be enabled
- the specific content type must be enabled
- `content_write` scope must be allowed

## OAuth Token Flow

`BetterTogether::Federation::OauthTokensController` implements a client-credentials flow for machine-to-machine federation.

Behavior:

1. requires `grant_type=client_credentials`
2. finds the active connection for the current source platform and `oauth_client_id`
3. authenticates the stored client secret
4. issues a connection-bound access token scoped by `FederationScopeAuthorizer`

This is not a browser sign-in flow and does not rely on a user session.

## Sync Flow

`BetterTogether::FederatedContentPullJob` is the async entrypoint for content pull.

High-level flow:

1. load `PlatformConnection`
2. mark sync started
3. call `FederatedContentPullService`
4. ingest returned seeds through `FederatedContentIngestService`
5. mark sync succeeded with cursor and item count
6. enqueue the next page if a cursor remains
7. on error, mark sync failed and re-raise

The sync queue is `platform_sync`.

## Privacy Boundary: Consent Layers

Four independent layers gate whether a specific content item is actually exported, all enforced
in `FederatedContentExportService#federation_consent_scoped`
(`app/services/better_together/content/federated_content_export_service.rb`):

1. **Connection-level** — `PlatformConnection#allows_content_type?` (from
   `PlatformConnectionFederationPolicy`) must return true for the item's content type. Checked in
   `eligible_records`, one layer above `federation_consent_scoped`.
2. **Person-level** — `Person#federate_content` (a Storext boolean, default `false`). The
   creator's global opt-in/opt-out, checked via a JSONB `preferences` predicate inside
   `federation_consent_scoped`.
3. **Item-level** — `federation_visibility` (`platform_default`/`federate`/`no_federate`),
   added by the `BetterTogether::Federatable` concern
   (`app/models/concerns/better_together/federatable.rb`, included in `Post`, `Page`, `Event`;
   `Content::Block` is out of scope). `no_federate` is excluded unconditionally by a leading
   `.where.not(federation_visibility: 'no_federate')`; `federate` satisfies the OR'd consent
   clause regardless of the creator's global preference; `platform_default` falls through to
   layer 2 unchanged.

4. **Per-connection grant** — `BetterTogether::FederationContentGrant` (`allowed` or `denied`) for this
   item and this connection, set through `Federatable#federation_content_grants_by_connection=`
   (the per-connection matrix on the post edit form). A `denied` grant excludes the item for that
   connection; an `allowed` grant includes it for that connection even when the creator has not opted
   in globally. No grant falls through to layers 2 and 3. Setting a connection to `platform_default`
   deletes its grant. `no_federate` (layer 3) still wins over an `allowed` grant.

Precedence, highest first: `federation_visibility = no_federate`, then an explicit grant for this connection,
then `federation_visibility = federate`, then the creator's `federate_content` preference.

`FederationScopeAuthorizer` and `Content::FederatedContentAuthorizer` remain connection/scope-level
only — neither was changed by the item-level work, since item consent is deliberately a lower
layer only the export service needs to know about.

Design and acceptance criteria: `docs/plans/federation-item-consent.md`.

## Planned (Not Yet Shipped): Identity/Attribution Consent

Content-level consent (above) is complete. **Identity consent — whether a federated item carries
the author's name/profile, or arrives as an anonymous/system item — is not.** That work is
tracked separately in [Federation Consent Gate + Person Identity Plan](../../plans/federation-consent-identity.md),
which introduces:

- federated person stubs (UUID-preserved minimal `Person` records on the destination platform)
- person-link claim and merge flows
- profile-change propagation

`FederatedSeedAttributes` (`app/services/better_together/seeds/federated_seed_attributes.rb`)
still exports posts/pages/events with no creator/author field — this is the specific gap that
plan closes. Do not assume author identity is protected just because content-level consent is
now member-controlled.

## Access tokens and connection credentials

`FederationAccessToken` (`better_together_federation_access_tokens`) is the short-lived bearer token issued by the OAuth flow. It belongs to a `PlatformConnection` and stores only a SHA-256 digest of the token (`token_digest`, unique); the plaintext exists in `token` only on the record that was just created and in the response. Columns: `scopes` (space separated), `expires_at`, `revoked_at`, `last_used_at`. `FederationAccessTokenIssuer.call(connection:, requested_scopes:)` asks `FederationScopeAuthorizer` for the granted scopes, raises when none are authorised, and creates the token with a default lifetime of 15 minutes (`DEFAULT_EXPIRES_IN`).

Lookup is `FederationAccessToken.find_active_by_plaintext(value)`: not revoked, not expired, and the connection `active`. `includes_scope?`, `revoke!` and `touch_last_used!` (at most once a minute) complete the model.

`PlatformConnectionOauthCredentials` gives each connection its client credentials: `oauth_client_id` (`ce-` plus 24 hex characters) and a 64-character secret generated on create. The secret is encrypted at rest and a bcrypt digest is stored; `authenticate_oauth_secret` checks the digest (falling back to a constant-time SHA-256 comparison for older rows) and `rotate_oauth_client_secret!` replaces both and clears the cached token.

## Sync tracking and the circuit breaker

`PlatformConnectionSyncTracking` keeps pull-sync bookkeeping in the connection's `settings` JSON: cursor, `last_sync_status` (`idle`, `running`, `succeeded`, `failed`), start, success and error times, last error message (500 characters), item count, failure streak and backoff. Values are written with `update_columns`, not `update!`, so frequent bookkeeping does not bump `lock_version` or fire callbacks.

- `mark_sync_started!`, `mark_sync_succeeded!` and `mark_sync_failed!` also write an activity record (`platform_connection.sync_started`, `sync_succeeded`, `sync_failed`) that the Federation Hub activity feed reads.
- A successful **final** page clears the failure streak and backoff; an intermediate page does not, so a connection that can only serve one page before failing cannot reset its own backoff.
- Failures back off exponentially from 300 seconds, capped at 6 hours (21,600), or the remote's own `retry_after` if longer (`sync_backoff_active?`).
- After 20 consecutive failures `trip_circuit_breaker!` sets the connection `suspended` with a real `update!`, so the status-change notifier fires, and records `sync_circuit_breaker_tripped`. `mark_sync_failed!` returns true in that case so `FederatedContentPullJob` stops retrying.

## Platform federation status

`PlatformFederationStatus` (included in `Platform`) answers whether a platform is `local_hosted?` or an `external_peer?`, whether it is a Community Engine (`community_engine?`, true for local platforms or `software_variant == 'community_engine'`), `federated?` (has a `federation_protocol`), its `effective_oauth_issuer_url` (the explicit issuer, or the resolved host URL for Community Engine platforms), `pending_host_connection_bootstrap?`, and `connected_platforms` (targets of active outgoing connections plus sources of active incoming ones).

## Notifiers

Federation changes notify people through `FederationVisibilityStatusNotifier` (creator told when an item's `federation_visibility` changes), `PlatformConnectionSubmittedNotifier`, `PlatformConnectionStatusNotifier` and `PlatformConnectionDigestNotifier`; see [Notifications System](notifications_system.md).

## Federation Hub

Members (not just platform managers) can see a summary of their own content's federation status
— counts by `federation_visibility` and recent items — at `/federation-hub`
(`app/controllers/better_together/federation_hub_controller.rb`), a top-level nav destination
alongside the Community/Exchange Hub, not a Host Dashboard tab. Platform managers additionally see
a connection-health summary card and a paginated activity feed
(`app/services/better_together/federation_hub/activity_feed_service.rb`), which queries
`BetterTogether::Activity` directly rather than the generic `ActivityPolicy::Scope` — that scope
hard-filters to public-privacy activities, which is wrong for connection audit activity that must
stay restricted to permission-holders.

## Related Files

- `app/models/better_together/platform_connection.rb`
- `app/models/concerns/better_together/platform_connection_federation_policy.rb`
- `app/models/concerns/better_together/federatable.rb`
- `app/models/concerns/better_together/platform_connection_sync_tracking.rb`
- `app/models/concerns/better_together/platform_connection_oauth_credentials.rb`
- `app/models/concerns/better_together/platform_federation_status.rb`
- `app/models/better_together/federation_access_token.rb`
- `app/models/better_together/federation_content_grant.rb`
- `app/services/better_together/federation_access_token_issuer.rb`
- `app/services/better_together/federation_scope_authorizer.rb`
- `app/services/better_together/content/federated_content_authorizer.rb`
- `app/services/better_together/content/federated_content_export_service.rb`
- `app/services/better_together/federation_hub/`
- `app/controllers/better_together/federation_hub_controller.rb`
- `app/controllers/better_together/federation/oauth_tokens_controller.rb`
- `app/jobs/better_together/federated_content_pull_job.rb`
