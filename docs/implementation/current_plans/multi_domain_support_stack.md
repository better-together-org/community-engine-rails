# Multi-domain support (stack MDS)

This note is the base of a stacked chain of pull requests. It carries no code. Its job is to keep one accurate, squash-ready description of the whole stack, so the single commit that lands on `main` explains every change in the chain.

Stack id: **MDS**. Every pull request title in the chain starts with `(MDS-n)`, where n is its position. MDS-0 is this note. Each later pull request is based on the previous branch and says "Stacked on #N". The chain starts from `main` after the hosted platform steward parity stack (HPS) lands.

## Why

One Community Engine app can serve several platforms, and each platform can have several domains. Domain resolution already picks the platform from the request hostname, but other parts of the app still assume one host:

- Background jobs and `deliver_later` mail run without the platform that queued them, so they fall back to the host platform and the global `APP_HOST`.
- Engine-level URL defaults (rake tasks, sitemaps, the OmniAuth full-host helper) use one global host.
- There is no single rule for secondary domains: whether they redirect to the primary, and which domain mail links use.
- Rails host authorization is a static list (`APP_HOSTS`, while docs say `ALLOWED_HOSTS`), not the set of active `PlatformDomain` rows.
- Tests cannot easily exercise several hostnames outside the browser: request, mailer and job specs set up hostnames by hand, and browser specs wipe the host's domain rows when they clean up.

## Rules for the whole stack

- One app instance and one port serve every hostname, as in production. Tests do not run several servers.
- A platform's own URL carries no port; the hostname selects the platform.
- Reserved and unknown hosts fail closed.

## Stack

| Id | Change | Status |
| --- | --- | --- |
| MDS-0 | This note and the squash-ready description | this PR |
| MDS-1 | Jobs and mailers carry the platform: `Current.platform` is serialized into jobs and restored, mail links use the platform's primary domain | in review |
| MDS-2 | Engine URL defaults resolve per platform instead of one global `APP_HOST` | in review |
| MDS-3 | Secondary-domain rule: redirect to the primary, mail links use the primary | in review |
| MDS-4 | Host authorization from active `PlatformDomain` rows, one documented env name | in review |
| MDS-5 | Multi-hostname test support: per-hostname helpers for request, mailer and job specs, browser specs map hostnames to the one server port at runtime, host domain rows healed after JS cleanup | planned |

## Out of scope

Wildcard zones, Cloudflare DNS and certificates, and HAProxy routing. They sit with the operator and provisioning work.

## Squash commit message

```
feat(platform): multi-domain support across jobs, mail, URLs and tests (MDS-0 to MDS-5)

- Jobs and mail carry the platform that queued them (MDS-1)
- Engine URL defaults resolve per platform (MDS-2)
- Secondary domains redirect to the primary and mail uses the primary (MDS-3)
- Host authorization follows active PlatformDomain rows (MDS-4)
- Specs exercise several hostnames outside the browser, and browser specs use one server port (MDS-5)
```

## Acceptance for the whole stack

- A job or mail queued on one platform renders links on that platform's primary domain.
- A request on a secondary domain redirects to the primary.
- An unknown hostname is refused; an active `PlatformDomain` is accepted without a config change.
- The suite runs the same hostname paths in request, mailer, job and browser specs.
