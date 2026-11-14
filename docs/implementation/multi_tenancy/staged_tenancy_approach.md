# Platform tenancy: the staged approach

**Status:** current direction (November 2026). Supersedes the schema-per-tenant plan and the runtime
contract in this folder, which remain as history.

## What exists today

Community Engine runs several platforms in one app and one database. A request is matched to a
platform by hostname (`PlatformContextMiddleware`, `PlatformDomain.resolve`), `Current.platform` is
set for the request, and rows carry a `platform_id`. Policies scope by platform by convention. There
is no schema switching, no database per tenant and no row level security yet.

## Decisions

1. **Row level multi-tenancy is the baseline.** Hardening it comes first.
2. **Accounts are per platform.** One person with two platforms has two accounts. Email is unique per
   `(platform_id, lower(email))`. There is no shared login and no shared session cookie domain.
3. **Schema or database per platform is the intended tier 3 option**, a separate app per customer, and
   is not built here. The row model is kept extractable (see "Design for extraction").
4. **Unknown hostnames fail closed** once more than one platform exists.

## Phases

| Phase | Goal |
|---|---|
| 0 | Security stop-gap: invitations, admin checks, OAuth apps, unknown hosts, social sign-in, JWT audience |
| 1 | Per platform accounts (existing accounts are backfilled to the host platform) |
| 2 | Isolation backstops: policy sweep, NOT NULL `platform_id`, composite uniqueness, job and mailer context, row level security behind a flag |
| 3 | Tenant infrastructure: shared integration store, storage, mail identity, domain verification, lifecycle |
| 4 | UX and accessibility |

## Rules for code in this repository

- Never call `permitted_to?('manage_platform')` without a record. Use `platform_manager?(platform)` or
  `host_platform_manager?`. A lint spec enforces this.
- A token, invitation, OAuth application or JWT is valid only on the platform that issued it.
- Anything a tenant can configure that makes the server reach out (OIDC issuers, webhooks, federation)
  must resolve DNS and refuse private ranges (`BetterTogether::SafeOutboundHost`).
- Issuer-based identity providers and their `trust_verified_email` flag are host manager only.
- Security-relevant tenancy events go through `BetterTogether::TenancyAudit.record`.
- Host apps must set `config.hosts` to the hostnames they serve. Fail-closed routing
  (`BetterTogether.fail_closed_unknown_hosts`, on outside the test environment) answers 404 for a
  hostname with no active `PlatformDomain` unless there is a single platform, the host equals the host
  platform's own URL, or the path is a health check (`/up`, `/health`, `/healthz`, `/health_check`).

## Design for extraction (tier 3)

Every tenant table carries `platform_id`; tenant tables reference only same-platform tenant rows or
global reference rows; cross-tenant reads go through one named helper; per platform settings and
secrets are keyed by `platform_id`. The requirements for the tier 3 project are written at the end of
Phase 3.

## JWT rotation

API JWTs now carry a `plt` (platform) claim and are rejected on any other platform. Tokens issued
before this release have no claim and are refused; they live one hour, so no manual rotation is needed.
