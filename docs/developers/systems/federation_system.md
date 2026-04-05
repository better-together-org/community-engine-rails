# Federation System

**Target Audience:** Developers and maintainers  
**Document Type:** System documentation  
**Last Updated:** March 30, 2026

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

## Privacy Boundary: Current Limitation

The current implementation is stronger at **operator-configured platform trust** than at **person-level federation consent**.

Today:

- platform operators can decide what a connection may share
- content and scope settings are explicit and fail closed when disabled
- there is not yet a completed person-level consent gate that prevents a member's content from being exported unless they explicitly opt in

Because of that gap, production activation should remain conservative until the planned consent architecture is complete.

## Planned Consent Architecture

The current plan is documented in [Federation Consent Gate + Person Identity Plan](../../plans/federation-consent-identity.md).

That plan introduces:

- person-level `federate_content` consent
- export gating based on that consent
- federated person stubs
- person-link claim and merge flows

This is planned architecture, not the completed current runtime.

## Related Files

- `app/models/better_together/platform_connection.rb`
- `app/models/concerns/better_together/platform_connection_federation_policy.rb`
- `app/services/better_together/federation_scope_authorizer.rb`
- `app/services/better_together/content/federated_content_authorizer.rb`
- `app/controllers/better_together/federation/oauth_tokens_controller.rb`
- `app/jobs/better_together/federated_content_pull_job.rb`
