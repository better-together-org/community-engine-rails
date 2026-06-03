# Federation Privacy and Consent

**Target Audience:** Platform organizers and network administrators  
**Document Type:** Operational privacy guide  
**Last Updated:** March 30, 2026

## Overview

Federation lets one Community Engine platform establish a directed `PlatformConnection` with another platform for mirrored content and machine-to-machine application programming interface (API) access.

This guide explains the current privacy and consent model as it exists in code today. It also documents the current safety boundary: federation controls are primarily platform-operator controls right now, not fully member-driven consent controls.

## Current Reality

Federation behavior is controlled on each `PlatformConnection` through:

- connection status: `pending`, `active`, `suspended`, `blocked`
- content sharing policy
- federation authentication policy
- per-content toggles:
  - posts
  - pages
  - events
- per-scope toggles:
  - identity
  - profile read
  - content read
  - linked content read
  - content write

These settings are normalized by the platform connection model before save. If sharing or authentication is set to `none`, the related toggles are switched off automatically.

## What Activation Enables

An **active** platform connection can enable two broad categories of sharing:

### Content mirroring

If the content sharing policy is set to a mirroring mode and a content type is enabled, the remote platform can pull that content into its own local mirrored copy.

Current mirrored content types are:

- posts
- pages
- events

### Federation authentication scopes

If federation authentication is enabled and the relevant scopes are allowed, a connected platform can request scoped access tokens for:

- identity read
- profile read
- content read
- linked content read
- content mirror write
- content publish write

The granted scopes are determined by the active directed connection and the connection's settings. Tokens are not general-purpose user tokens; they are connection-bound machine credentials.

## Privacy and Consent Limits Today

The most important limitation is this:

**The current shipping federation model is still operator-configured, not person-consent-complete.**

In practical terms:

- a platform organizer can configure what types of content are shared
- a platform organizer can configure what machine scopes are allowed
- the current implementation does **not** yet provide a completed per-person consent gate for federation export
- the current implementation does **not** yet provide a completed member-facing consent workflow for "my content may leave this platform"

This means platform-level permission to federate is more mature than person-level consent to federate.

## Operational Safety Rule

Until the planned person-level federation consent architecture is shipped, production hosts should treat federation activation as a high-trust operator feature and fail closed.

Recommended rule:

1. Do **not** activate platform connections for general production content sharing unless the participating communities have explicitly agreed to the scope of sharing.
2. Use `pending` or `suspended` while negotiating policy and governance.
3. For testing or staged rollout, use only non-sensitive content and the smallest possible scope set.
4. Prefer `none` for federation authentication until there is a clear operational reason to grant more.
5. Grant only the specific content types and scopes needed for the immediate use case.

## Minimum-Scope Recommendations

When a platform connection is necessary:

### Lowest-risk setup

- status remains `pending` during review
- content sharing policy: `none`
- federation auth policy: `none`
- all content toggles off
- all scope toggles off

Use this while exchanging metadata, documenting responsibilities, or preparing the connection without enabling any live sharing.

### Limited read-only content sync

If a platform must read mirrored content:

- enable only the required content type
- prefer read-only authentication over write scopes
- keep linked content read disabled unless there is a specific private-sharing need
- leave publish-back disabled unless both platforms have explicitly agreed to editorial and moderation responsibilities

### Highest-risk setup

The following combination deserves explicit governance review before activation:

- mirrored or publish-back content sharing
- identity scope enabled
- profile read enabled
- content write enabled
- linked content read enabled

This combination creates the broadest cross-platform data and authority surface.

## Questions Organizers Should Answer Before Activation

Before approving a platform connection, document answers to these questions:

1. What exact content types are allowed to leave the source platform?
2. Why is each requested scope necessary?
3. Who on each platform is accountable for moderation, corrections, and takedowns?
4. How will affected members be informed that cross-platform sharing exists?
5. What is the rollback plan if the relationship becomes unsafe?
6. What data should never be shared over this connection?

If these answers are not clear, leave the connection inactive.

## Suspension and Rollback

If a platform connection becomes unsafe or unclear:

- suspend the connection immediately
- rotate the OAuth client secret if trust is in doubt
- review recent sync failures and content imports
- verify whether any mirrored content needs manual moderation or removal

Suspension is the reversible first response. It stops ongoing trust without requiring permanent deletion of the relationship record.

## Current Permissions Model

Viewing and managing platform connections is intentionally separate from general platform administration.

Current dedicated permissions are:

- `manage_network_connections`
- `approve_network_connections`

Use the smallest role set possible for these permissions. Not every platform organizer should automatically have federation authority.

## Related Documents

- [Security and Privacy Management](security_privacy.md)
- [Platform Administration Guide](platform_administration.md)
- [Privacy-First Principles](../shared/privacy_principles.md)
- [Federation Consent Gate + Person Identity Plan](../plans/federation-consent-identity.md)
- [Federated Seed and Sync Handoff](../implementation/multi_tenancy/federated_seed_and_sync_handoff_2026-03-12.md)
