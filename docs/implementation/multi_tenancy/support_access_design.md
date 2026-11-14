# Support requests and time limited support access: design for later

Status: designed, not started. Nothing here is implemented. Written 2026-11-12 on `feature/multi-tenancy-v2` (draft PR #2165). This closes the design question left open as P1-7 in `phase_0_1_review_notes.md`.

## Problem

Accounts are per platform and a Warden hook logs out a session that reaches another platform. That is correct, but it leaves host staff with no sanctioned way to help a hosted tenant, and it leaves tenants with no structured way to ask. An end user also has no structured way to ask their own platform's manager for help.

## Decisions

1. One mechanism, two uses. A `SupportRequest` is a subtype of the existing request model (`BetterTogether::Joatu::Request`), like `MembershipRequest` and `PersonAccessGrantRequest`.
   - Tenant use: a manager of a hosted platform asks the host platform for help. The request is addressed to the host platform.
   - End user use: any signed in member asks the managers of their own platform. The request is addressed to that platform.
   - Both use the same model, form, notification and review screens. The only difference is the target platform and who is notified.
2. Support access is opt in and granted by the tenant. A host staff session can pass the cross platform check only while a grant from the tenant's manager is active.
3. A grant creates no account, membership or role on the tenant. The session carries a read only support permission set for that tenant, evaluated in code and never stored as role rows.
4. Every request made under a grant is audited with `BetterTogether::TenancyAudit`.
5. Implementation is deferred until the task feature exists, so review and follow up can run through tasks.

## Model

`SupportRequest < Joatu::Request`
- `target`: the platform being asked for help (host platform for a tenant request, the user's own platform for an end user request).
- `platform_id`: the platform the requester belongs to (set by `PlatformRecord`).
- Fields: `summary`, `details` (rich text), `category` (use Joatu categories, "Support Requests"), `urgency` (existing), `requested_access` (boolean: asks for a support access grant), `status` (existing exchange status).
- Validation: `target_type` is `BetterTogether::Platform`. A request with `requested_access` is allowed only when the requester is a manager of a platform that is not the host and the target is the host platform. End user requests never carry an access grant.
- A request has many `support_access_grants`.

`SupportAccessGrant` (new table, platform scoped to the tenant)
- `platform_id`: the tenant being accessed.
- `support_request_id`, `granted_by_id` (tenant manager person), `grantee_user_id` (named host staff user; one grant per named person, never a role or group).
- `permission_set` (string key, default `read_only`; the set itself lives in code).
- `starts_at`, `expires_at` (required, maximum 7 days, default 24 hours), `revoked_at`, `revoked_by_id`, `last_used_at`.
- Unique active grant per `(platform_id, grantee_user_id)`.

## Who is notified

- Tenant request to the host: every person who holds the `platform_tech_support` role on the host platform (seeded in `access_control_builder.rb`), plus host platform managers as fallback when nobody holds that role.
- End user request to their own platform: managers of that platform (`platform_manager` permission), with the same fallback.
- Use a new `SupportRequestSubmittedNotifier` in the existing notifier style (action cable plus email, `required_param :support_request`, locale aware title and body), triggered by an `after_create_commit` on the request like `MembershipRequest#notify_reviewers_of_submission`. Requester gets a decision notifier on status change.
- The notification URL goes to a review screen. Until the task feature exists nothing else subscribes. When it does, the request instruments `support_requested.better_together` (same pattern as `platform_deletion_requested.better_together`) so a task is created for the recipients.

## Flow

1. A tenant manager (or end user) opens "Request support" and submits a `SupportRequest`.
2. Recipients are notified and review it. They can reply, mark in progress, or close it.
3. If `requested_access` is set, the tenant manager sees a "Grant support access" action on their own request, picks the named host staff user (from the people who were notified and who responded), the expiry, and confirms. This creates the `SupportAccessGrant`.
4. The named host staff user signs in on the host platform and opens the tenant through a "Support access" link. The Warden hook checks for an active grant (platform, user, not expired, not revoked). If found the session is allowed to continue on that tenant in support mode. If not, behaviour is unchanged (logout).
5. In support mode, `Current.support_session` is set. Policies and `Member#permitted_to?` evaluate the read only permission set instead of the user's host roles, so a host steward gets no write power on the tenant. Writes are refused with a clear message.
6. A fixed banner shows who is acting, until when, and a "Leave support mode" control. The tenant manager sees active grants and can revoke at any time.
7. Grants expire on their own. Expiry and revoke end the session on its next request.

## Audit

`TenancyAudit.record` events: `support_request.created`, `support_access.granted`, `support_access.used` (once per session start), `support_access.request` (path, verb, status, record type and id only, never bodies or params), `support_access.revoked`, `support_access.expired`, `support_access.denied`. The tenant manager can see their own platform's events in a log screen. Events carry ids and platform ids, never personal data.

## Safety rules

- Fail closed: any error resolving a grant means no access.
- Read only means HTTP GET and HEAD only, enforced in the controller layer, plus policy checks. Exports, downloads of private blobs, and personal messages are excluded from the read only set.
- No impersonation: the user stays their host account. No tenant session cookie is minted for the tenant user.
- A grant never lets the host staff grant themselves access. Only a manager of the tenant can create one.
- Nobody can be granted access to a platform they already manage as a normal member.
- Rate limit grant creation and cap active grants per platform.

## Schema and cache implications

- New tables: `better_together_support_requests` is not needed if the subtype lives in the existing Joatu requests table (STI); add the columns above there or in a details table. Add `better_together_support_access_grants`.
- Permission cache: `Member#permitted_to?` caches per record. Support mode must bypass or key the cache on the support session so a host steward's host permissions never leak into the tenant, and tenant permissions never leak back.
- Platform deletion and person deletion executors must delete or end grants.

## Views, docs, tests (when built)

- Views: request form, request review, grant form, active grants list for tenants, support mode banner. Each ships with stable DOM ids, a `spec/dom_contracts` spec, desktop and mobile screenshots (annotated and plain), and an axe feature spec.
- Four locales (en, es, fr, uk).
- Diagrams: sequence diagram of the flow and an ERD update, in `docs/diagrams/source`, rendered with `bin/render_diagrams`.
- Specs: request created and notified (tenant and end user paths); wrong role not notified; grant created only by tenant manager; session allowed with grant and logged out without, after expiry, after revoke; read only enforced on writes; cache isolation; audit events emitted; deletion executors clear grants.
- Staging rehearsal with two platforms before any deploy.

## Open questions

- Who exactly is notified when nobody holds the support role: all host managers, or only the platform steward?
- Should the tenant manager be able to pick any host user, or only users who responded to the request?
- Maximum grant length (7 days proposed) and whether renewals need a new request.
- Should end user support requests be visible to other managers of the platform, or only the notified ones?
- Does read only cover all of the tenant's private content, or should some areas (messages, personal data) be fully excluded? Proposed: fully excluded.
- Whether the tenant sees a live indicator that host staff are currently in support mode.

## Related

- `phase_0_1_review_notes.md` (P1-7), draft PR #2165, roadmap issue #2170, community decoupling issue #2169.
