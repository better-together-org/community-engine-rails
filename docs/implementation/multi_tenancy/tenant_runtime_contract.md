# Federated Platform Runtime Contract

**Date:** March 11, 2026  
**Status:** Draft architecture baseline  
**Purpose:** Canonical runtime contract for local CE tenancy plus federated platform networking

---

## Summary

This document defines how CE should behave at runtime under the revised architecture:

- locally hosted platforms still use schema-per-platform tenancy
- each platform keeps its own local accounts, people, memberships, and onboarding
- CE-powered platforms can authenticate against one another via OAuth
- linked accounts and configured platform connections form a network graph
- authorized remote content can be mirrored locally for feed/search/display and refreshed regularly

It assumes the ownership rules in `tenant_data_ownership_matrix.md` and the authorization cleanup in `federated_rbac_reassessment_and_coverage_plan.md`.

---

## Local Platform Resolution

### Request Input

Each request is resolved from:

- request host
- optional subdomain
- route and path

### Resolution Rules For Locally Hosted Platforms

1. Look up the request host in `public.better_together_platforms`.
2. Match exact custom domain first.
3. Match known subdomain + base domain second.
4. Load the local hosted platform metadata from `public`.
5. Resolve the tenant schema name.
6. Switch to that schema before controller logic runs.

### External Platform Records

External peer platforms in `public.better_together_platforms` are not directly switched into as local tenant schemas. They are peer metadata records used for:

- OAuth provider/client configuration
- connection requests and accepted network edges
- remote content sync configuration
- source attribution for mirrored content

### Public-Schema Exceptions

The following flows run in `public` without switching to a local tenant schema:

- provisioning flows before a tenant exists
- fleet-admin and support routes spanning local tenants
- peer platform discovery, trust bootstrap, and local routing fallbacks

Unknown hosts must fail closed.

---

## Local Context Contract

### Required `Current` Fields For Local Platform Requests

| Field | Meaning |
|-------|---------|
| `Current.platform` | Local hosted platform metadata resolved from `public` |
| `Current.tenant_schema` | Active local tenant schema |
| `Current.community` | Current community when route or UI establishes it |
| `Current.user` | Authenticated local account for the active platform |
| `Current.person` | Local person profile for the active platform |

### Context Rules

- `Current.platform` and `Current.tenant_schema` are always set for local platform requests.
- `Current.user` and `Current.person` are local to the active platform.
- Cross-platform OAuth does not replace local accounts; it is an authentication and authorization bridge into local account creation, login, and sync flows.
- If a federated sign-in succeeds but the local platform requires invitation or onboarding, the request must enter a join/onboarding gate before the user can participate in private spaces.

---

## Federated Sign-In Contract

### CE-to-CE OAuth

Each CE-powered platform should be able to act as:

- an OAuth provider for its own users
- an OAuth client to peer CE platforms

### Sign-In Flow

1. A user on platform B chooses to sign in with a connected CE platform account from platform A.
2. Platform B authenticates the user via OAuth against platform A.
3. Platform B receives authorized identity claims and permitted scopes.
4. Platform B checks local admission rules:
   - invitation requirement
   - onboarding wizard requirement
   - agreement acceptance requirement
5. Platform B either:
   - links to an existing local account
   - creates a new local account and local person after the user joins
   - or holds the authenticated session in a join-pending state until onboarding is complete

### Admission Rules

Federated sign-in must never bypass:

- invitation-only restrictions
- platform-specific onboarding steps
- agreement acceptance requirements
- private community access gates

### Account Materialization

The current planning default is:

- federated sign-in authenticates first
- the local platform then prompts the user to join if a local account and person do not yet exist
- successful join creates the local records and records the cross-platform account linkage

---

## Community And Personal Community Rules

- Each platform has exactly one host community.
- Each person may have one personal community inside each platform where they hold a local account.
- Person-to-person connection requests may be used to manage participation in personal communities.
- Community-owned records remain local to the platform and derive ownership from explicit community context.

The host community must not become a universal silent fallback for every record type.

---

## Connection Request Contract

### Shared Primitive

`Joatu::Request` gains a `ConnectionRequest` subtype used for:

- person to person connections
- person to community join/connection requests
- community to community connections
- platform to platform connections

### Acceptance Behavior

Acceptance creates:

- the network edge or local relationship edge
- any required agreement state for auth, sync, or shared data permissions
- any pending next-step workflow such as onboarding, membership creation, or sync bootstrap

### Agreement Rules

Agreements are used to record:

- consent for shared authentication
- mirrored-content sharing and refresh rights
- publish-back or bi-directional sync rights
- network-connection operating terms

---

## Authorization Contract

### Local RBAC Remains Authoritative

Every federated action still begins with local RBAC inside the active tenant schema.

Local roles and permissions decide whether a user may attempt to:

- manage a platform connection
- configure CE OAuth trust
- enable mirrored-content ingestion
- moderate a mirrored record locally
- request or approve publish-back

### Additional Network Gates

For cross-platform actions, local RBAC is necessary but not sufficient.

The runtime must also check:

- active connection state
- active agreements and granted scopes
- platform sharing policy
- record provenance and sync state

### Mirrored Content Rules

- mirrored content is identified by `record.platform_id != Current.platform.id`
- local platform roles may govern local visibility, curation, and moderation of the mirror
- canonical remote ownership stays with the source platform
- publish-back requires an explicit permission family plus an active agreement allowing it

---

## Network Feed And Mirrored Content

### Network Layers

The platform network is composed of two layers:

- manager-configured peer/member platform connections
- person-linked platform account connections

### Feed Rules

People can see:

- local platform content
- network content shared by directly connected platforms that opted in
- content relevant to their linked platform accounts where permissions allow it

### Mirroring Rules

- remote CE content authorized for sharing is mirrored locally with source attribution and sync metadata
- mirror refresh runs on a schedule and may also be event-triggered
- mirrored content is shown in local feeds and search subject to local and remote permissions
- bi-directional sync is allowed only when both platforms and agreements authorize publishing both ways

### Source Of Truth

- canonical ownership remains on the source platform
- mirrored local copies exist for caching, feed aggregation, search, and controlled publication workflows

---

## Background Jobs

### Local Job Context

Every local job payload must include:

- local platform identifier or tenant schema identity
- optional local community identifier
- optional network sync context when acting on peer content or linked accounts

### Network Sync Context

When a job involves a peer platform, it must also include:

- source or target platform identifier
- linkage or agreement identifier when relevant
- sync direction (`ingest`, `refresh`, `publish`)

Jobs must fail closed if local tenant context, peer auth context, or agreement requirements are missing.

---

## Mailers And Notifications

- Mailers render in one local platform context.
- Network invitations, connection requests, and join prompts may reference remote platforms but still use local branding and policy context.
- Product notifications remain local to one platform.
- Cross-platform sync telemetry and delivery diagnostics belong to fleet/admin operations, not the local product notification stream.

---

## Cross-Tenant And Cross-Platform Administration

### Local Fleet Admin

Fleet-admin routes operate across locally hosted tenant schemas for:

- local tenant inventory
- provisioning status
- backup and restore oversight
- sync diagnostics

### Cross-Platform Network Admin

Platform managers operate within their local platform and can manage:

- outbound and inbound platform connection requests
- trust and sharing settings
- mirrored content policies
- connected account and peer platform status

These are product-level platform-manager actions, not fleet-admin actions.

---

## Failure And Safety Rules

- Unknown hosts fail closed.
- Federated sign-in without local admission must stop in a join/onboarding state.
- Missing or revoked OAuth linkage must block sync and sign-in continuation.
- Missing agreement consent must block content sharing and publish-back actions.
- Remote platform unavailability must degrade gracefully without corrupting mirrored content state.
- Bi-directional sync must never occur without explicit opt-in on both sides.

---

## Interface Additions Implied By This Contract

- local platform routing metadata in `public`
- CE OAuth provider/client support for peer platforms
- linked-account records between local accounts and remote platform accounts
- `ConnectionRequest` subtype on `Joatu::Request`
- accepted connection edge model for people, communities, and platforms
- mirrored-content records with source and sync metadata
- agreement-backed sharing and auth scopes for sync and publish rights

---

## Review Checklist

- A local platform request can be traced from host resolution to schema switch to local account context.
- A federated sign-in can be traced from peer OAuth to local join/onboarding gate to local account creation or linkage.
- A connection request can be traced from request creation to relationship edge plus agreement activation.
- Mirrored content can be traced from remote authorization to local ingest, refresh, and optional publish-back behavior.
