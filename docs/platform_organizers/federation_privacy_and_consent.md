# Federation Privacy and Consent

**Target Audience:** Platform organizers, network administrators, and members
**Document Type:** Operational privacy guide
**Last Updated:** July 19, 2026

## Overview

Federation lets one Community Engine platform establish a directed `PlatformConnection` with another platform for mirrored content and machine-to-machine application programming interface (API) access.

This guide explains the current privacy and consent model as it exists in code today. Federation
consent now has three layers: platform-operator controls (this document's original focus),
a member's own global federation preference, and — as of the per-item consent work
(`docs/plans/federation-item-consent.md`) — a per-item override any member can set on their own
content. Identity/attribution consent (whether a person's *name*, not just their content,
federates) is tracked separately in `docs/plans/federation-consent-identity.md` and is not yet
complete.

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

## Privacy and Consent Layers Today

Three independent layers now compose to decide whether a specific piece of content actually
leaves a platform:

1. **Connection-level** (organizer-configured): per-connection, per-content-type toggles
   (`share_posts`, `share_pages`, `share_events`) plus the scope toggles described above. A
   content type must be enabled on the connection before anything of that type can be exported
   to it at all.
2. **Person-level** (`federate_content`, a member-facing preference under Settings → Privacy &
   Federation, default off): a global switch for that member's own content. When off, none of a
   member's public content is federated to any connection, regardless of the connection's
   settings.
3. **Item-level** (`federation_visibility` on individual posts, pages, and events — see
   `docs/plans/federation-item-consent.md`): a per-item override next to that item's privacy
   control, with three states:
   - **Use platform default** (the default) — follows the member's global `federate_content`
     preference, exactly as before this feature shipped.
   - **Always federate** — this specific item is eligible for export even if the member's global
     preference is off.
   - **Never federate** — this specific item is excluded even if the member's global preference
     is on and the connection allows the content type. This always wins.

Members can also see a summary of their own content's federation status — counts by
`federation_visibility` state and their most recently affected items — at `/federation-hub`,
reachable from the main navigation for any signed-in person, not just platform organizers.

**What is still not covered:** federation currently has no per-connection selection at the item
level — a member cannot say "federate this item to Platform A but not Platform B" (see the
"Explicitly deferred" section of `docs/plans/federation-item-consent.md`). Identity/attribution
consent — whether a federated item carries the author's name and profile, versus arriving as an
anonymous/system item — is tracked separately in `docs/plans/federation-consent-identity.md` and
is not yet complete; do not assume author identity is protected just because content-level
consent is now member-controlled.

## Operational Safety Rule

Content- and item-level consent are now member-controlled (see above), but identity/attribution
consent is not yet complete (`docs/plans/federation-consent-identity.md`). Until that ships,
production hosts should still treat federation activation as a high-trust operator feature and
fail closed.

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
- [Safety and Federation Review Workflow](../developers/systems/safety_and_federation_review_workflow.md)
- [Privacy-First Principles](../shared/privacy_principles.md)
- [Federation Consent Gate + Person Identity Plan](../plans/federation-consent-identity.md)
- [Federation Item Consent (Tri-State) + Federation Hub Plan](../plans/federation-item-consent.md)
- [Federated Seed and Sync Handoff](../implementation/multi_tenancy/federated_seed_and_sync_handoff_2026-03-12.md)
