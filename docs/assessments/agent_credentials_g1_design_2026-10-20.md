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

## Decisions (2026-10-20, Rob)

- Agent keys are always bound to one platform. A global robot needs one grant per platform.
- Grant scopes reuse the Doorkeeper scope names, one vocabulary.
- The Robot bot-access token stays as is and is documented below. It is not migrated.

## Credential types on a Robot

| | Bot-access token (0.11.0, unchanged) | Agent credential (G1) |
|---|---|---|
| Purpose | Anonymous-style read access and form-check bypass for the HTML web app | Authenticated actions through REST API and MCP |
| Mechanism | `X-Better-Together-Robot-Token: <identifier>.<secret>`, SHA256 digest in `Robot#settings`, honoured only when no human is signed in | Doorkeeper application bound to a robot, bearer token |
| Authority | Static scopes: `read_public_content`, `read_community_content`, `read_private_content`, `submit_public_forms`, `submit_authenticated_forms` | Intersection of token scopes, `AgentGrant` scopes and the operator's current permissions |
| Operator | None | Required, recorded on every action |
| Community limit | None | Per community |
| Consumers | `ApplicationPolicy` and `PagePolicy` privacy filtering, `BotProtectedSubmissions`, `ActiveStorageGate` | `Api::ApplicationController`, `Mcp::PunditContext` |
| Docs | `docs/developers/systems/bot_safety_system.md` | this document, then the agent credentials system doc |

The two never share a header or a table. A robot may hold both; they are evaluated
by different code paths and neither widens the other. Possible later hygiene for the
bot-access token (last-used timestamp, rotation notices) is tracked separately.
