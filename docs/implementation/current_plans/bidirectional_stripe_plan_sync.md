# Plan: Bi-Directional Stripe Plan/Price Sync

## TL;DR

Add `stripe_product_id`, `sync_source`, and `synced_to_stripe_at` columns to `better_together_billing_plans`; wire an `after_commit` → `SyncPlanToStripeJob` → `StripePlanSync` service that pushes name/description/active changes to Stripe Product/Price; subscribe to `price.*` and `product.*` Stripe webhooks via a new `StripePriceSync` service routed through the existing `StripeEventProcessor` pipeline; guard the webhook loop with `sync_source`; backfill `stripe_product_id` for existing plans via a maintenance job. Price immutable fields (amount_cents, currency, billing_interval) are protected by a new model validator. Pre-existing index view bug fixed as part of Phase 0.

---

## Phase 0 — Pre-existing Bug Fix (blocks all testing)

**Why now:** `app/views/better_together/billing/plans/index.html.erb:47` calls `plan.subscriptions.where(status: 'active').count` against the removed `status` column on `better_together_billing_subscriptions`. Will `PG::UndefinedColumn` in production once migration runs.

1. Fix `index.html.erb:47`:
   - Change to `plan.subscriptions.joins(:pay_subscription).merge(Pay::Subscription.where(status: 'active')).count`
   - Move into a scoped helper method on `Plan` (e.g. `active_subscription_count`) to keep view clean
2. Add `active_subscription_count` method on `BetterTogether::Billing::Plan` (or scope)
3. Add test in `spec/models/better_together/billing/plan_spec.rb`

**Files:** `app/models/better_together/billing/plan.rb`, `app/views/better_together/billing/plans/index.html.erb`, `spec/models/better_together/billing/plan_spec.rb`

---

## Phase 1 — Schema Migration

Single migration: `AddStripeSyncFieldsToBillingPlans`

New columns on `better_together_billing_plans`:
- `stripe_product_id` string, nullable (Stripe `prod_xxx` ID; populated on first push)
- `sync_source` string, nullable (`'stripe_webhook'` signals inbound; nil = app-originated)
- `synced_to_stripe_at` datetime, nullable (last successful outbound push)
- `latest_stripe_event_id` string, nullable (Stripe event ID that last mutated the plan via webhook; aids audit trail)

Constraint changes:
- Index `stripe_product_id` (unique where not null, using partial index)
- Index `stripe_price_id` (unique — prevents ambiguous lookup in `StripePriceSync` and `StripeSubscriptionSync`; previously unconstrained)

Idempotency: guard all with `column_exists?` / `index_name_exists?`

> **Note:** The `stripe_price_id` uniqueness index may fail if duplicate values exist. Run a one-time data check before the migration: `BetterTogether::Billing::Plan.group(:stripe_price_id).having('count(*) > 1').count` and resolve any duplicates first.

**File:** `db/migrate/YYYYMMDD_add_stripe_sync_fields_to_billing_plans.rb`

---

## Phase 2 — Price Immutability Validator

Add to `BetterTogether::Billing::Plan`:
- `validate :price_fields_immutable_after_create` — rejects changes to `amount_cents`, `currency`, `billing_interval` if `stripe_price_id` is persisted and any of those fields changed
- Error message: i18n key `better_together.billing.plans.errors.price_fields_immutable`
- Add `validates :stripe_price_id, uniqueness: true` to enforce uniqueness at the model layer
- Define `self.permitted_attributes` (for update) and `self.permitted_attributes_for_create` (adds price fields) on the **model** following project convention. Controllers call `Plan.permitted_attributes` / `Plan.permitted_attributes_for_create` instead of hard-coding permit lists.

Rationale: Stripe Prices are immutable for these fields. Allowing changes would silently diverge local state from Stripe without this guard. Placing permitted attribute lists on the model follows the project-wide pattern (see copilot-instructions.md).

**Files:** `app/models/better_together/billing/plan.rb`, `app/controllers/better_together/billing/plans_controller.rb`, all 4 locale files

---

## Phase 3 — `StripePlanSync` Service (App → Stripe)

New file: `app/services/better_together/billing/stripe_plan_sync.rb`

```ruby
Result = Struct.new(:synced, :billing_plan, :reason, keyword_init: true)

def call(plan:)
```

Logic:
1. Return `reason: :webhook_initiated` if `plan.sync_source == 'stripe_webhook'` → also resets `sync_source` to nil via `update_columns` (single call with `sync_source: nil`)
2. Return `reason: :no_price_id` if `plan.stripe_price_id.blank?`
3. If `plan.stripe_product_id.blank?`: fetch `Stripe::Price.retrieve(plan.stripe_price_id)` → read `.product` field → `plan.update_columns(stripe_product_id: product_id)`
4. `Stripe::Product.update(stripe_product_id, { name: plan.name, description: plan.description, metadata: { bt_plan_id: plan.id, bt_plan_identifier: plan.identifier } })`
5. `Stripe::Price.update(stripe_price_id, { nickname: plan.name, active: plan.active?, metadata: { bt_plan_id: plan.id, bt_plan_identifier: plan.identifier } })`
6. `plan.update_columns(synced_to_stripe_at: Time.current, sync_source: nil)` — single atomic call; skips validations intentionally (system-managed fields only)
7. Return `Result.new(synced: true, billing_plan: plan, reason: :synced)`

Error handling:
- Rescue `Stripe::StripeError` → return `synced: false, reason: :stripe_error`
- Rescue `ActiveRecord::RecordNotFound` → return `synced: false, reason: :plan_not_found`

> **Note on `update_columns`:** Bypasses validations and `lock_version` (optimistic locking). Acceptable here because only system-managed sync fields are written, not user-entered data.

Uses defensive `extract_value` helpers (same pattern as `StripeFinancialEventSync`).

**File:** `app/services/better_together/billing/stripe_plan_sync.rb`

---

## Phase 4 — `SyncPlanToStripeJob` (App → Stripe async)

New file: `app/jobs/better_together/billing/sync_plan_to_stripe_job.rb`

Pattern: identical to `ProcessStripeEventJob`:
- `queue_as :default`
- `retry_on StandardError, wait: :polynomially_longer, attempts: 10`
- `perform(plan_id)`: `plan = BetterTogether::Billing::Plan.find(plan_id)` → `StripePlanSync.new.call(plan:)` → log result

**File:** `app/jobs/better_together/billing/sync_plan_to_stripe_job.rb`

---

## Phase 5 — Plan Model `after_commit` Callback

Add to `BetterTogether::Billing::Plan`:
```ruby
after_commit :enqueue_stripe_sync!, on: %i[create update]

private

def enqueue_stripe_sync!
  SyncPlanToStripeJob.perform_later(id)
end
```

Pattern matches `Platform#after_commit :sync_primary_platform_domain!, on: %i[create update]`.

The loop guard lives in the job/service (reads `sync_source`), not the callback — consistent with how other CE models defer guard logic to their service layer.

**File:** `app/models/better_together/billing/plan.rb`

---

## Phase 6 — `StripePriceSync` Service (Stripe → App)

New file: `app/services/better_together/billing/stripe_price_sync.rb`

```ruby
Result = Struct.new(:synced, :billing_plan, :reason, keyword_init: true)

def call(event:)
```

**Data ownership boundary (critical):**
| Field | Source of truth | StripePriceSync action |
|---|---|---|
| `amount_cents`, `currency`, `billing_interval` | Stripe (immutable) | Never written — blocked by Phase 2 validator |
| `active` | Stripe (bidirectional) | Synced inbound from `price.updated` / `price.deleted` / `product.deleted` |
| `name`, `description` | CE (CE pushes to Stripe) | **NOT** overwritten from inbound Stripe events |

Routing by `event.type`:
- `price.updated`: `Plan.find_by(stripe_price_id: event.data.object.id)` → sync `active` field only; check if Stripe billing interval is in `BILLING_INTERVALS` — if not, return `reason: :unsupported_interval`
- `price.deleted`: find by `stripe_price_id` → `update_columns(active: false, sync_source: 'stripe_webhook', latest_stripe_event_id: event.id, synced_to_stripe_at: Time.current)`
- `product.updated`: `Plan.find_by(stripe_product_id: event.data.object.id)` → sync `active` only (do **not** overwrite `name`/`description` — CE owns those fields)
- `product.deleted`: find by `stripe_product_id` → `update_columns(active: false, sync_source: 'stripe_webhook', latest_stripe_event_id: event.id, synced_to_stripe_at: Time.current)`
- `price.created`: no-op for now (plan was created manually or via the "Provision" path); return `reason: :no_action_needed`

Guard: if plan not found → return `synced: false, reason: :plan_not_found` (not all prices/products belong to CE)

**Loop guard — single `update_columns` call (critical):** All field updates from `StripePriceSync` MUST use a single `update_columns(field: value, sync_source: 'stripe_webhook', latest_stripe_event_id: event.id, synced_to_stripe_at: Time.current)` call. **Never** use `update!` or `save` followed by a separate `update_columns` — this creates a race window where `after_commit` fires with `sync_source: nil` and re-enqueues the outbound sync job, causing a webhook loop.

**Subscriber impact:** When `product.deleted` deactivates a plan, existing subscriptions on that plan are NOT cancelled — subscribers continue on their current terms; no new subscriptions can be created. Operator alert should be triggered (consider Noticed notification for platform managers).

Uses same defensive `extract_value` helpers.

**File:** `app/services/better_together/billing/stripe_price_sync.rb`

---

## Phase 7 — Wire into Existing Event Pipeline

### 7a. `StripeEventDispatcher` — add event types

`StripeEventDispatcher` registers the Stripe event types CE wants to receive and dispatches inbound Stripe events to `ProcessStripeEventJob`. Add to `EVENT_TYPES` array:
```ruby
'stripe.price.created'
'stripe.price.updated'
'stripe.price.deleted'
'stripe.product.updated'
'stripe.product.deleted'
```

> **Webhook auth note:** No changes needed to the Stripe webhook controller. Stripe-Signature verification via `Stripe::Webhook.construct_event` is already handled by the existing controller before events reach this pipeline.

**File:** `app/services/better_together/billing/stripe_event_dispatcher.rb`

### 7b. `StripeEventProcessor` — new routing arm

Add private methods:
- `plan_event?(event)` — `event.type.in?(%w[price.created price.updated price.deleted product.updated product.deleted])`
- `sync_plan_event(event)` — `price_sync.call(event:)`
- `price_sync` — memoized `StripePriceSync.new`

Add to `sync_result_for` chain (after `financial_event?`, before nil fallback):
```ruby
return sync_plan_event(event) if plan_event?(event)
```

Update `relevant_event?` to include `plan_event?(event)`.

Update `processed_sync_result?`: plan events use `sync_result&.synced`.

`billable_owner_for` already returns nil gracefully for events with no customer context (plan events have no `Pay::Customer`). `event_success_attributes` already uses `sync_result.try(:billing_subscription)` which returns nil safely. No changes needed there.

**File:** `app/services/better_together/billing/stripe_event_processor.rb`

---

## Phase 8 — Backfill Job

New file: `app/jobs/better_together/billing/backfill_stripe_product_ids_job.rb`

Pattern: matches `ReconcileStripeBillableOwnerBillingScanJob` (`:maintenance` queue, Redis lock):
- Finds all Plans where `stripe_product_id.nil? && stripe_price_id.present?`
- For each: enqueues `SyncPlanToStripeJob` with a per-job delay (`perform_in(index * 2.seconds, plan.id)`) to avoid Stripe API rate limit bursts
- Respects `LOCK_KEY`/`LOCK_TTL` Redis pattern to prevent concurrent runs

Separately: a one-time data fix can be run as a Sidekiq `perform_now` call or Rake task after deploy.

**File:** `app/jobs/better_together/billing/backfill_stripe_product_ids_job.rb`

---

## Phase 9 — i18n Keys

Add to all 4 locale files (`en`, `es`, `fr`, `uk`) under `better_together.billing.plans`:
- `errors.price_fields_immutable` — "Pricing fields (amount, currency, interval) cannot be changed once linked to a Stripe Price. Create a new plan instead."
- `synced_to_stripe_at_label` — "Last synced to Stripe"
- `stripe_product_id_label` — "Stripe Product ID"
- `sync_status_synced` — "Synced"
- `sync_status_pending` — "Pending sync"
- `sync_status_never` — "Not yet synced"
- `notifications.plan_deactivated_by_stripe` — "Plan '%{plan_name}' was deactivated by a Stripe webhook event."

---

## Phase 10 — Specs

New spec files:
- `spec/services/better_together/billing/stripe_plan_sync_spec.rb` — loop guard, no price_id early return, product_id lookup, Stripe API calls stubbed, success result, Stripe::StripeError handling
- `spec/services/better_together/billing/stripe_price_sync_spec.rb` — each event type, plan not found, active toggle, name/description sync, sets sync_source
- `spec/jobs/better_together/billing/sync_plan_to_stripe_job_spec.rb` — enqueues, calls service, handles missing plan
- `spec/jobs/better_together/billing/backfill_stripe_product_ids_job_spec.rb` — Redis lock, enqueues SyncPlanToStripeJob per plan

Updated spec files:
- `spec/models/better_together/billing/plan_spec.rb` — price fields immutability validator, `active_subscription_count` method, `after_commit` enqueues job
- `spec/services/better_together/billing/stripe_event_processor_spec.rb` — price/product events route to StripePriceSync
- `spec/services/better_together/billing/stripe_event_dispatcher_spec.rb` (if exists) — EVENT_TYPES includes new types

---

## Relevant Files

- `app/models/better_together/billing/plan.rb` — add callback, validator, `active_subscription_count`
- `app/controllers/better_together/billing/plans_controller.rb` — split `plan_params` for create vs update
- `app/views/better_together/billing/plans/index.html.erb` — fix broken `where(status: 'active')`
- `app/services/better_together/billing/stripe_plan_sync.rb` — NEW
- `app/services/better_together/billing/stripe_price_sync.rb` — NEW
- `app/services/better_together/billing/stripe_event_dispatcher.rb` — add 5 event types
- `app/services/better_together/billing/stripe_event_processor.rb` — new routing arm + predicate
- `app/jobs/better_together/billing/sync_plan_to_stripe_job.rb` — NEW
- `app/jobs/better_together/billing/backfill_stripe_product_ids_job.rb` — NEW
- `db/migrate/YYYYMMDD_add_stripe_sync_fields_to_billing_plans.rb` — NEW
- `spec/dummy/db/schema.rb` — updated by migration
- `config/locales/en.yml` (+ es, fr, uk) — new keys

---

## Verification

1. `bin/dc-run bundle exec prspec spec/models/better_together/billing/plan_spec.rb`
2. `bin/dc-run bundle exec prspec spec/services/better_together/billing/stripe_plan_sync_spec.rb`
3. `bin/dc-run bundle exec prspec spec/services/better_together/billing/stripe_price_sync_spec.rb`
4. `bin/dc-run bundle exec prspec spec/services/better_together/billing/stripe_event_processor_spec.rb`
5. `bin/dc-run bundle exec rubocop -A` on all changed files
6. `bin/dc-run bin/i18n health`
7. `bin/parallel-setup` then `bin/dc-run bin/ci`

---

## Decisions

- **`stripe_price_id` on create stays manual** — operators paste it from Stripe Dashboard or create via Stripe CLI. `StripePlanSync` populates `stripe_product_id` automatically on first push by calling `Stripe::Price.retrieve`. A future "Provision in Stripe" controller action (explicit button) is the path to full auto-creation; out of scope here.
- **Price field mutation (amount_cents, currency, billing_interval) is blocked** — Stripe Prices are immutable for these fields. The validator prevents silent divergence. Operators create a new plan when pricing changes are needed. Subscriber migration tooling is a separate future issue.
- **Loop guard via `sync_source`** — same column name as `Billing::Subscription#sync_source`, consistent pattern. `StripePriceSync` sets `sync_source: 'stripe_webhook'` atomically in the same `update_columns` call as the data change. `StripePlanSync` reads it at the start of the job and skips if set. Never use a separate save followed by `update_columns` — the `after_commit` fires between them, creating a loop.
- **`price.created` is no-op** — CE does not auto-create local plans from new Stripe Prices. Requires an operator decision (human-in-the-loop).
- **`product.deleted` deactivates the plan** — rather than destroying it (consistent with `destroy? = false` policy). Existing subscriptions are not cancelled.
- **CE owns `name`/`description`; Stripe owns `active`** — `StripePriceSync` never overwrites plan name or description from inbound Stripe events. CE pushes those fields to Stripe; Stripe is authoritative only for billing state (`active`).
- **Unsupported billing intervals** — If a Stripe Price has an interval not in `BILLING_INTERVALS` (e.g., `week`, `day`), `StripePriceSync` returns `reason: :unsupported_interval` without erroring.

## Further Considerations

1. **`stripe_price_id` writability on update** — the `Plan.permitted_attributes_for_update` list must exclude `stripe_price_id`, `amount_cents`, `currency`, and `billing_interval`. Model-level uniqueness and immutability validators provide defence-in-depth.
2. **Stripe API key in test environment** — `StripePlanSync` and `StripePriceSync` make direct Stripe API calls. All specs must stub `Stripe::Price`, `Stripe::Product` via `allow(Stripe::Price).to receive(:retrieve)` etc. Use the existing spec convention (check `spec/services/better_together/billing/stripe_subscription_sync_spec.rb` for pattern).
3. **Backfill timing** — run `BackfillStripeProductIdsJob` immediately after deploy via a Sidekiq `perform_now` call in a one-time task, or schedule it via `sidekiq_cron.yml`. Don't block the migration on it.
4. **Test factory default** — the `:better_together_billing_plan` factory should have `stripe_price_id: nil` as default (or set it only in billing-specific contexts) so that non-billing integration tests do not enqueue `SyncPlanToStripeJob` unnecessarily. Verify after Phase 5 that existing factories still work.
