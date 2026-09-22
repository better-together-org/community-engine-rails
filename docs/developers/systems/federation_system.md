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

Three independent layers gate whether a specific content item is actually exported, all enforced
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
- `app/services/better_together/federation_scope_authorizer.rb`
- `app/services/better_together/content/federated_content_authorizer.rb`
- `app/services/better_together/content/federated_content_export_service.rb`
- `app/services/better_together/federation_hub/`
- `app/controllers/better_together/federation_hub_controller.rb`
- `app/controllers/better_together/federation/oauth_tokens_controller.rb`
- `app/jobs/better_together/federated_content_pull_job.rb`
