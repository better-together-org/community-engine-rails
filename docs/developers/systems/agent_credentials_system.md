# Agent Credentials System

Robots act through the REST API and MCP with credentials that are delegated to a human
operator, limited to one platform and optionally one community. Design rationale and the
comparison with the Robot bot-access token: [agent credentials design](../../assessments/agent_credentials_g1_design_2026-10-20.md).

## Model

- `OauthApplication` gains `robot_id`, `community_id`, `last_used_at`, `rotated_at`. An
  application with `robot_id` is an agent credential and must belong to a platform.
  Applications without it keep acting as their owner.
- `AgentGrant` (`better_together_agent_grants`) records the delegation: robot, operator
  (Person), platform, optional community, scopes (Doorkeeper scope names), expiry and
  revocation. Scopes `admin` and `mcp_access` need a platform manager operator, and a
  community grant needs authority over that community.

## Request flow

`Api::TokenActor.from_token(token)` is the single resolver for REST and MCP. It reads only
the bearer token. For an agent credential it finds the live grant and, when active, sets
`Current.robot`, `Current.person` (operator), `Current.agent` (robot),
`Current.credential_community` and `Current.platform`.

Effective authority is the intersection of three things, checked on every request:

1. token scopes and grant scopes (`TokenActor#scopes`; unscoped endpoints still need a
   `read*` scope for reads and `write*` or `admin` for writes),
2. the operator's current permissions, so demoting the operator narrows the robot at once,
3. the credential community: `Member#permitted_to?` evaluates every permission against that
   community only, and API resources return only that community's records (404 elsewhere).

A credential without a live grant fails closed with 403 (REST) or stays anonymous (MCP).

## Diagrams

- [Entity relationships](../../diagrams/source/agent_credentials_erd.mmd)
- [Request flow](../../diagrams/source/agent_credentials_request_flow.mmd)

## Request checks

An agent request is accepted only when all of these hold on every request:

- The access token is accessible (not revoked or expired). Dead tokens get 401 everywhere.
- A live grant exists for the robot on the credential's platform (and community, if limited).
- The operator's user account is confirmed and the robot is active.
- The request arrived on the platform the credential was issued for. A request resolving
  to a different platform is refused with 403.
- If the actor cannot be resolved, the request is refused with 403. It never falls back to
  acting as the application owner.

## Scope granularity (known limit)

Only controllers that declare required scopes (`webhooks`, `webhook_endpoints`) are checked
against specific scopes. On every other endpoint an agent is checked by HTTP method only: a
GET needs any scope starting with `read`, and a write needs any scope starting with `write`
or `admin`. A grant with `read_people` therefore also reads other endpoints the operator can
read. The operator's permissions and the community limit still bound every request. Per-endpoint
scopes and default-deny for unscoped endpoints are queued for G2.

## G2 queue

- Declare required scopes on the remaining API controllers and deny agents by default on
  unscoped endpoints.
- Credential and grant management endpoints, `GET /api/v1/me/credential`, per-token throttles.
- Populate `last_used_at` and `rotated_at`.
- Tie each application to its grant (validate robot is global or on the grant platform,
  community belongs to the platform, grantor holds the authority) and make grant selection
  deterministic (partial unique index on active grants). Follow-up PR before G2 endpoints.
- Foreign key `on_delete` for `robot_id` and `platform_id`, and a `(robot_id, platform_id)`
  active-grant index.

## Not in this slice

Attribution columns and UI ("Robot X on behalf of Person Y") are G1b. Credential and grant
management endpoints, `me/credential` introspection and per-token throttles are G2.
Models without a `community_id` are hidden from community-limited credentials until a
resource opts in.
