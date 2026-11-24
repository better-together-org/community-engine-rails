# Membership baseline and lifecycle stack (MBR)

Stacked PRs that make platform and community memberships a managed, auditable part of the engine. Stack id: **MBR**. Each PR bases on the one before it. The base PR (MBR-0) carries only this note; its squash message itemizes the whole stack.

## Why

Assessment of `main` and `feature/billing` (2026-11-24, tracked under #1443):

- Self-registration created a host-community membership only. Platform membership existed only for invited people, stewards, and a one-off backfill, so billing, quotas and per-platform roles could not rely on it.
- Memberships could not be edited (community), had no visible state, no start or end dates, no history, and members could not leave.
- Several code paths silently bypassed approval or referred to roles that are not seeded.

Decisions: every account holds the baseline `platform_member` role on its own platform (free, read-only, never billed). Paid and elevated roles are separate rows that stack on it. Ended memberships keep a history row. Free and paid memberships share one table, distinguished by a source field.

## The stack

| PR | Title | What it does |
|---|---|---|
| MBR-0 | This note | Base PR, draft, squash target for the stack |
| MBR-1 | Baseline platform membership | `BaselinePlatformMembership` service called from sign-up and OAuth sign-in; `BackfillBaselinePlatformMemberships` data migration for accounts created since the last backfill; notification suppression accessor |
| MBR-2 | Membership correctness fixes | Email confirmation no longer activates memberships that await approval; wizard and tenant provisioning create active steward memberships; request reviewer roles use seeded identifiers; API community scoping fixed; dead routes and views removed; policy scopes honour `active` |
| MBR-3 | Membership lifecycle | `starts_at`, `ends_at`, `ended_reason`, `suspended` and `ended` states, soft end instead of delete, audit trail, shared concern replacing the two duplicated models |
| MBR-4 | Membership management UI | Community role editing, state and dates on member cards, detail page, self-leave, last-steward guard, pending queue for managers |
| MBR-5 | Billing integration | Entitlement grants link to membership dates and source |

MBR-3 to MBR-5 are planned and not started; this table is updated as each PR opens.

## Squash message (kept current)

```
Membership baseline and lifecycle (MBR)

- Every account gets the platform_member role on its own platform at sign-up and OAuth sign-in; backfill for existing accounts (MBR-1)
- Fix approval bypass on email confirmation, pending steward memberships from the wizard and provisioning, unseeded reviewer role names, API scoping, dead routes (MBR-2)
- Membership lifecycle: dates, suspended/ended states, history, audit (MBR-3, planned)
- Management UI: edit, state, detail, leave, last-steward guard (MBR-4, planned)
- Billing grants linked to membership dates and source (MBR-5, planned)
```
