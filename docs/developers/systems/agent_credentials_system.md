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

## Not in this slice

Attribution columns and UI ("Robot X on behalf of Person Y") are G1b. Credential and grant
management endpoints, `me/credential` introspection and per-token throttles are G2.
Models without a `community_id` are hidden from community-limited credentials until a
resource opts in.
