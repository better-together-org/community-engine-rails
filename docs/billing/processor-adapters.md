# Billing foundation and payment processor adapters

Community Engine core ships a vendor-neutral billing foundation: the `pay` gem, the Pay tables, host billing configuration, and a processor adapter contract. Core never calls a payment vendor SDK. A processor extension gem (for example `better_together-billing-stripe`) registers an adapter and does the vendor work. With no adapter registered, billing stays off and nothing else changes.

## Host requirements

- A top-level `ApplicationRecord` (every `rails new` app has one). `Pay::ApplicationRecord` inherits from it.
- uuid primary keys, like every CE table. The Pay migration creates uuid keys.
- Run the engine migrations (`20261015120000_create_better_together_pay_tables`). It is safe on a schema that already has Pay tables.

## Configuration

Billing identity has no built-in defaults. Until the three required variables are set, `BetterTogether::Billing::Configuration.ready?` is false and a one-line warning is logged at boot.

| Variable | Required | Purpose |
|---|---|---|
| `PAY_BUSINESS_NAME` | yes | Legal or trading name shown by the processor |
| `PAY_BUSINESS_ADDRESS` | yes | Business address |
| `PAY_SUPPORT_EMAIL` | yes | Support contact |
| `BT_BILLING_ENABLED` | yes | Master switch (`true` to enable) |
| `BT_BILLING_DEFAULT_CURRENCY` | no | Preselects the currency when creating a plan |
| `BT_BILLING_DEFAULT_COUNTRY` | by feature | Used when an owner has no country (merchant onboarding) |
| `PAY_APPLICATION_NAME` | no | Defaults to `Community Engine` |

`BetterTogether::Billing.enabled?` is true only when the flag is on, the identity is configured, and at least one processor is registered.

## Writing an adapter

Subclass `BetterTogether::Billing::ProcessorAdapter` and register it from your engine:

```ruby
initializer 'my_processor.register' do
  BetterTogether::Billing.register_processor(:my_processor, -> { MyProcessor::Adapter.new })
end
```

Implement `processor_name`, `sanitize_payload`, `capabilities`, `webhook_event_types`, and the methods for each capability you advertise. `ProcessorAdapter::CAPABILITY_METHODS` lists the methods and keywords per capability. The contract version is checked when the adapter is built; a mismatch raises `ContractError`. Run the shared examples in `spec/support/shared_examples/billing_processor_adapter.rb` against your adapter.

Core owns idempotency keys and money state. Money-moving calls always receive an `idempotency_key` that the adapter must pass through to the processor.

## Event pipeline

Processors deliver webhooks through Pay. Core logs, retries and replays them; the adapter only understands the vendor payload.

1. After boot, core subscribes each registered adapter's `webhook_event_types` to Pay's delegator.
2. `adapter.normalize_webhook(vendor_event)` returns `{ event_id:, event_type:, payload: }`. Core records it once per `(processor, event_id)` in `better_together_billing_events`; a duplicate delivery is ignored.
3. `ProcessBillingEventJob` is enqueued with the **event id only**, so payloads never appear in Redis or job logs.
4. `adapter.process_event(event:)` reads `event.payload` and returns a `Billing::EventResult`: `processed`, `ignored`, `alerted` (handled, but an operator should look), or `retry` (a prerequisite such as a not-yet-synced subscription is missing).

Status values: `pending`, `processed`, `ignored`, `alerted`, `failed`, `dead_lettered`, `replayed`. Only `failed` and `dead_lettered` count as problems, so unrelated or informational events do not raise alerts.

### Retries, dead letters and replay

- A failed or `retry` result is retried by ActiveJob up to `Billing::Event::MAX_ATTEMPTS` (5) times. `processed_at` is set only on a final outcome.
- Hourly, `DeadLetterStaleBillingEventsJob` moves events that exhausted their retries (`retries_exhausted`) or made no progress for 6 hours (`stale_unresolved_drift`) to `dead_lettered`.
- `Billing::ReplayEvent` re-enqueues a dead-lettered event. It refuses events whose payload was redacted or whose processor is no longer installed.

### Payload retention

Raw payloads are kept for `BT_BILLING_EVENT_PAYLOAD_RETENTION_DAYS` (default 30) after processing. A daily job then replaces each with `adapter.sanitize_payload(payload)`, or with just `id` and `type` if the adapter is gone. Sanitizers must remove personal data and secrets.

## Plan catalog

A `Billing::Plan` links one price at one processor (`processor` + `processor_price_id`; a price id is unique per processor). Platform stewards manage plans under the host dashboard (Billing Plans). Plans have no default currency; amounts are stored in the currency's smallest unit, and zero-decimal currencies such as JPY are displayed without dividing by 100 (`Billing::Currency`).

- **Creating a plan** requires an installed processor. If the processor supports `plan_sync`, `verify_price` must confirm the price exists in your account, so a steward cannot link a price from someone else's account. A failed lookup rejects the plan (fail closed).
- **Price fields** (amount, currency, interval) cannot change after a price is linked.
- **Sync:** saving a plan enqueues `SyncPlanJob`, which calls `adapter.sync_plan(plan:)` when the processor supports `plan_sync`. Code applying a change that came from the processor sets `plan.skip_processor_sync = true` for that save, so it is not pushed straight back. The flag is not stored, so later admin edits always sync.
