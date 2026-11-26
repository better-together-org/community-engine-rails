# Hosted platform steward parity (stack HPS)

This note is the base of a stacked chain of pull requests. It carries no code. Its job is to keep one accurate, squash-ready description of the whole stack, so the single commit that lands on `main` explains every change in the chain.

Stack id: **HPS**. Every pull request title in the chain starts with `(HPS-n)`, where n is its position. HPS-0 is this note. Each later pull request is based on the previous branch and says "Stacked on #N".

## Why

A steward of a hosted platform should be able to manage their own platform the way the host platform's steward manages the host. Today most admin surfaces already work for them, but a few do not, and a few leak or over-grant:

- The host dashboard checks the real host platform, so a hosted steward is denied on their own landing page.
- The dashboard counts and recent records are global, so opening it up without scoping would show other platforms' data.
- The roles and permissions index pages show counts across every platform.
- Feature and quota grants can be given to themselves by a steward.
- A steward can claim any unique hostname for their platform.
- A hosted platform has no navigation of its own, so it inherits the host's menu.

Closing these lets an operator configure hosted platforms by hand today, while the automated provisioning, Cloudflare and remote operator work is built.

## Stack

| Id | Change | Status |
| --- | --- | --- |
| HPS-0 | This note and the squash-ready description | this PR |
| HPS-1 | Host dashboard scoped to the platform being viewed and authorized against it; `Platform has_many :pages` | merged into this branch (#2363) |
| HPS-2 | RBAC index navigation counts scoped to the platform being viewed | merged into this branch (#2364) |
| HPS-3 | Feature access and quota grants follow the governing operator, not the platform itself | merged into this branch (#2365) |
| HPS-4 | Domain guardrails: allowed zone or operator-created, reserved names blocked, steward-created hostnames start inactive | merged into this branch (#2366) |
| HPS-5 | Platform-owned navigation seeded at provisioning, so a hosted platform no longer shows the host menu | merged into this branch (#2370) |
| HPS-6 | Manual hosted-platform provisioning runbook, steward smoke-test checklist, and the provisioning wizard assessment | merged into this branch (#2371) |

Follow-up inside this stack when its subsystem is touched: an access contract for platform administration (no contract covers the host dashboard or platform records yet).

## Decision: user and people permissions stay opt-in

The first plan for this stack added `manage_platform_users`, `list_person` and `update_person` to the steward and manager roles. That was dropped. Those permissions are opt-in for every default role, including the host platform's steward, by the least-privilege decision in f86f1722f and the people access contract. A hosted steward already has exactly the same limits as the host steward, so this is not a parity gap. A platform that wants user or people administration grants it explicitly.

## Out of scope for this stack

Self-serve provisioning form, steward invitation by email, the Cloudflare extension gem, association enforcement and the remote operator handshake. They follow this stack and are tracked in the larger plan.

## Squash commit message

```
feat(platform): hosted platform steward parity (HPS-0 to HPS-6)

- Host dashboard authorizes against the current platform and scopes its counts and records to it (HPS-1)
- Platform has_many pages (HPS-1)
- Roles and permissions index counts are scoped to the platform being viewed (HPS-2)
- Feature access and quota grants are administered by the governing operator: the host steward for the host and for hosted platforms with no operator, the local operator steward (billing scope) where an association is in force, and nobody on this instance where a remote operator governs (HPS-3)
- Hostnames must sit in an allowed zone or be operator-created, reserved names are blocked, steward-created hostnames start inactive (HPS-4)
- Hosted platforms get their own navigation area at provisioning (HPS-5)
- Runbook for manual hosted-platform provisioning, the steward smoke test, and an assessment with a phased plan for a seed-selecting provisioning wizard (HPS-6)
```

## Acceptance for the whole stack

- A steward of a hosted platform can sign in on the platform's own domain, reach the dashboard, and manage members, roles, navigation, pages, theme and domain requests.
- No page of the stack shows or edits another platform's data, and host-only surfaces stay denied.
- A steward cannot grant themselves features or quota, and cannot activate a hostname the operator has not approved.
- A runtime smoke test with a real hosted steward passes on staging.
