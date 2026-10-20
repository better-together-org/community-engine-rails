# Agent credentials, delegation and attribution: G1 design

Status: draft for review (2026-10-20). No code yet.

## Goal

Robots and other automated callers act through the REST API and MCP with scoped,
community-limited credentials, on behalf of a named human operator. Every action
is credited to the robot directly and to its operator.

## Current state (verified on main at 3db2d35ca)

- Machine credentials are Doorkeeper `OauthApplication` rows (owner Person, platform
  scoped, no community, coarse scopes). `Robot` has its own bot-access token (SHA256
  digest in `settings`, content scopes only) that the REST API does not consume.
- `Api::ApplicationController#current_user` resolves a `client_credentials` token to
  the application owner's user, so the robot is not represented. It sets
  `Current.agent = Current.person`.
- `Mcp::PunditContext.extract_user_from_doorkeeper` uses `resource_owner_id` only, so
  `client_credentials` tokens become anonymous in MCP.
- Scope checks are opt-in per controller (`require_oauth_scopes`) and absent for
  Devise-JWT requests.
- `Authorship` already stores a polymorphic author (Person or Robot) plus a Person
  `creator`, which fits robot-plus-operator attribution. Activity and audit records
  have no actor/operator pair.

## Decision 1: extend Doorkeeper, do not add a parallel key model

Reasons: token hashing, expiry, revocation, introspection and the existing host UI
and rswag docs are reused. New columns on `better_together_oauth_applications`:

- `robot_id` (nullable FK): the actor this application authenticates as.
- `community_id` (nullable FK): scope limit; null means platform-wide.
- `last_used_at`, `rotated_at`.

A key with `robot_id` set is an agent credential. Keys without it keep today's
behaviour (acts as owner) so existing integrations do not change.

## Decision 2: `AgentGrant` records the delegation

New table `better_together_agent_grants`: `robot_id`, `operator_id` (Person),
`community_id` (nullable), `scopes` (string array), `expires_at`, `revoked_at`,
`granted_by_id`, `platform_id`. A grant is the only way a robot gets authority. It
is revocable by the operator or a community/platform admin and is itself audited.

Effective permission for a request is the intersection of:
1. the token's Doorkeeper scopes,
2. the robot's active grant scopes for the token's community,
3. what the operator can do right now (`operator.permitted_to?` in that community).

Rule 3 is evaluated on every request, so demoting the operator immediately narrows
the robot. Issuing a grant or key is refused if it would exceed the grantor's own
permissions.

## Decision 3: one resolver for REST and MCP

`BetterTogether::Api::TokenActor` (value object: `robot`, `operator`, `application`,
`community`, `scopes`) built only from the bearer token. Never from params or
headers. `Api::ApplicationController` and `Mcp::PunditContext` both call it.

For an agent token: `Current.robot = robot`, `Current.person = operator`,
`Current.agent = robot`, new `Current.credential_community`. Pundit receives the
operator's user, wrapped so policies can ask `acting_as_agent?` and apply the
intersection above. This also closes the MCP anonymous-resolution gap.

## Decision 4: central community scoping

Enforced in `ApplicationPolicy` (`credential_scope` check inside `Scope#resolve`
and a record-level guard) plus JSONAPI `records` scoping, not per controller, so new
endpoints inherit it. Cross-community requests return 404, matching the existing
policy-error convention. Devise-JWT requests keep current behaviour.

## Decision 5: dual attribution

- Authored content: `Authorship.author` = robot, `creator_id` = operator (existing
  slots, no migration).
- Activity and audit rows (`PublicActivity` via `TrackedActivity`, `WebhookDelivery`,
  later `PlatformApiCall`): add `actor_type`/`actor_id` and `on_behalf_of_id`.
  Additive, nullable migrations with existence guards.
- New `Attributable` concern exposing `acting_agent` and `operator`, read from
  `Current` so it works in jobs when the owner is passed explicitly.
- UI and exports show "Robot X on behalf of Person Y". `Creatable#creator` stays
  Person-only.

## Scopes

Add granular scopes through the registry so provider gems extend them without
editing core: `read_platform_integrations`, `manage_platform_integrations`,
`manage_identity_providers`, `manage_oauth_clients`, `run_platform_actions:<kind>`,
`read_webhook_events`, `manage_agent_grants`. Destructive actions need an extra scope.

## Safety

- Secrets shown once, stored hashed (already true for Doorkeeper applications).
- Per-token Rack::Attack throttles (G2).
- Grant and key issuance emit notifications to the operator and community admins.
- No secret values in API responses or audit payloads.

## PR split

1. **G1a**: migrations (application columns, `agent_grants`), `TokenActor`, `Current`
   wiring for REST and MCP, policy intersection and community scoping. Specs:
   privilege escalation, operator demotion, cross-community isolation, MCP parity.
2. **G1b**: attribution columns, `Attributable`, activity/authorship display, Mermaid
   ERD, screenshots and dom_contracts for the attribution UI.
3. **G2**: credential and grant management endpoints (JSONAPI), `me/credential`
   introspection, per-token throttles, rswag specs.

## Open questions

- Is a robot bound to one platform or allowed global (the `Robot` model supports
  both)? Proposal: agent keys are always platform-bound; global robots need one
  grant per platform.
- Should `AgentGrant` scopes reuse Doorkeeper scope names or a separate permission
  vocabulary? Proposal: reuse scope names, one vocabulary.
- Migrate the existing Robot bot-access token to this model or leave it for public
  content access? Proposal: leave it; it serves a different read-only purpose.
