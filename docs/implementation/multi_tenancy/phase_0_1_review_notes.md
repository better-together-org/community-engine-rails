# Tenancy phases 0 and 1: review notes

This branch (`feature/multi-tenancy-v2`) implements the security stop gap (phase 0) and per platform accounts (phase 1) from the tenancy plan. It was built without a reviewer present, so every decision made on the reviewer's behalf and every open question is listed here. Nothing is merged or deployed.

## What changed

Phase 0
- Invitation redemption is bound to the issuing platform and to roles the inviter may grant.
- Unscoped `manage_platform` checks (Sidekiq, MiniProfiler, Doorkeeper admin, seeds, `/host` gate) became host or record scoped.
- Doorkeeper applications and tokens work only on their own platform; `trusted?` is limited to host managers on the host.
- Unknown hosts fail closed (not found), with a health path allowlist.
- OpenID Connect: issuer creation and `trust_verified_email` are host manager only, issuer hosts are checked against private ranges including after DNS resolution, raw provider payloads are scrubbed of tokens, `uid` widened to 255, configuration changes are audited, onboarding follows approval rules and waits for confirmation.
- JWTs carry a platform audience claim. The login throttle key includes the host and reads Devise params.

Phase 1
- `users.platform_id` NOT NULL with a foreign key; email unique per `(platform_id, lower(email))`; Devise lookups (sign in, confirmation, recovery, unlock, reset token) scoped to `Current.platform`; a Warden hook logs out a session that reaches another platform; OAuth linking searches only the current platform.
- Migrations backfill existing users, invitations and OAuth records with the host platform. No production account has access to several platforms, so there is nothing to split. Other platform rows are external (OAuth providers, federation).
- The platform memberships controller accepts only members of that platform and platform roles.

## Decisions I made (please confirm or reverse)

1. Fail closed for unknown hosts is on outside the test environment and off in tests (`BetterTogether.fail_closed_unknown_hosts`). A single non external platform install keeps the old fallback. The dummy app does not set `config.hosts`; host apps should.
2. Invitations with a NULL `platform_id` are backfilled to the host platform by migration; any that remain NULL cannot be redeemed.
3. OAuth applications, tokens and grants with no platform are backfilled to the host platform; the runtime fallback to the host is only defensive.
4. A tenant application can still hold admin or MCP scopes if its owner manages that tenant platform; it only works on that platform.
5. OAuth linking requires `user.platform_id` to equal the sign in platform.
7. JWTs issued before this release are refused (one hour lifetime).
8. The migration backfills `users.platform_id` with the host platform and raises if any NULL remains.

10. No same-email note on the sign up page (P1-2). Platforms are separately branded with no visible link between them, so sign up and sign in are expected to be single platform. Dropped by decision.
11. No platform identity cue in the header (P1-8). Platform branding already shows where a person is. Dropped by decision.

12. No separate leave platform feature. An account belongs to one platform, so the existing deletion request flow is the way to leave. The last steward of a platform cannot request or execute deletion of their account (request model, both controllers and `PersonDeletionExecutor` refuse). They are sent to a platform removal request form (`PlatformDeletionRequest`). No task model exists yet, so creating a request instruments `platform_deletion_requested.better_together`; host stewards are not notified until the task feature subscribes to it. `PersonHardDeletionExecutor` (operator rake) is intentionally unguarded. See `docs/end_users/account_deletion_requests.md`.

## Uncertainties and gaps

- DNS rebinding between the issuer check and the connection remains a small window.
- Not implemented from phase 0: refused redemption audit event, search and blob fallbacks, navigation lookup and short link policy scoping (phase 2).
- Not implemented from phase 1: host staff support access (P1-7). Each view change needs screenshots, DOM ids and a DOM contract spec.
- Deletion views have screenshots, a DOM contract spec and diagrams; no axe scan was added for them. Schema diagrams were regenerated with `bin/export_schema_diagrams`.
- `spec/requests/better_together/event_invitations_spec.rb:124` was already failing before this work.
- The Postgres test container can segfault under load; wait for `pg_isready` and rerun.
- A global `Resolv` stub in `spec/support/outbound_dns_stub.rb` keeps specs offline; it hides real DNS behaviour from specs outside the SSRF specs.
