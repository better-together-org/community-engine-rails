# Hosted billing roadmap

The billing foundation is designed so two later capabilities fit without reworking it.
Neither is implemented yet. This page records what is already in place for them and what
is deliberately left for later.

1. **A different processor configuration per platform.**
2. **Member communities that bill through the platform defining and managing their own
   plans** (hosted billing).

## Already in place

- **A tenant on every billing record.** Plans, events and the Pay tables carry a required
  `platform_id` with no ambient default ([platform_isolation.md](platform_isolation.md)).
- **A processor context on every adapter call.** `BetterTogether::Billing::ProcessorContext`
  names the platform and processor account; adapters never read global environment
  variables. Today `Billing::Configuration.context_for(platform, processor)` returns an
  environment-backed context for the host platform only. Later it can return a
  database-backed per-platform configuration.
- **Per-platform enablement.** `Billing.enabled?(platform)` and
  `Configuration.processors_for(platform)`; a platform with no context has billing off.
- **Owner-shaped management.** Routes, controller scoping and policies are written
  against a *billing owner*, which is the current platform today. Everything goes through
  one policy question, `manage_billing?(owner)`.
- **Per-platform uniqueness.** A plan `identifier` is unique per platform, not globally;
  processor price ids stay unique per processor so one tenant cannot claim another's.
- **Attributable webhooks.** Events carry `platform_id`; an adapter's `normalize_webhook`
  can return `platform_id:` or an `account_ref:` that core maps to a platform.

## Left for later

| Capability | What it needs |
|---|---|
| Per-platform processor configuration | A model modelled on `StorageConfiguration` (`belongs_to :platform`, credentials encrypted with `encrypts_billing_attribute`), a management page, and a `context_for` that reads it. |
| Per-platform webhook endpoints | One signing secret per platform, so the endpoint can tell which platform a delivery is for before it parses it. |
| Community-defined plans | A nullable polymorphic `seller` on plans (a community), the matching change to the `(platform_id, identifier)` uniqueness, a community-scoped route using the same `concern :billing_plans` in `config/routes/billing.rb`, and a community UI. |
| A community billing permission | `manage_community_billing`, separate from broader community editing or member management, used by `manage_billing?(community)`. The platform equivalent today is `manage_platform`. |
| Connected / merchant accounts and fee splits | The merchant account chunk (A9) and the processor extension's Connect support. |

## Rules to carry forward

- Never expose Pay's unscoped `payment_processor`; offer `billing_customer(platform:)`.
- Every new billing table is platform-bound and ties children to parents with composite
  foreign keys.
- Keep maintenance sweeps per record; they are the only cross-tenant operations.
