# Billing foundation and payment processor adapters

Community Engine core ships a vendor-neutral billing foundation: the `pay` gem, the Pay tables, host billing configuration, and a processor adapter contract. Core never calls a payment vendor SDK. A processor extension gem (for example `better_together-billing-stripe`) registers an adapter and does the vendor work. With no adapter registered, billing stays off and nothing else changes.

## Host requirements

- Active Record Encryption keys (`bin/rails db:encryption:init`, stored in credentials or environment variables). Billing encrypts payment data at rest; see [encryption.md](encryption.md).
- A `billing` Sidekiq queue with a high weight and ideally a dedicated capsule; see [../production/billing_queue_rollout.md](../production/billing_queue_rollout.md).
- Run the engine migrations (`20261015120000_create_better_together_pay_tables`). The Pay tables are owned by Community Engine: uuid keys, a required `platform_id` on every table that holds tenant data, and encrypted columns stored as `text`. No billing data exists to migrate, so the migration does not reconcile older Pay installs.

Pay's models inherit from `BetterTogether::Billing::PayRecord`, an abstract class the engine provides (`Pay.model_parent_class`), so a host does **not** need a top-level `ApplicationRecord` for billing.

## Configuration

Billing identity has no built-in defaults. Until the three required variables are set, `BetterTogether::Billing::Configuration.ready?` is false. A host that has switched billing on (`BT_BILLING_ENABLED`) but is missing variables gets a one-line warning at boot; a host that never asked for billing sees nothing.

| Variable | Required | Purpose |
|---|---|---|
| `PAY_BUSINESS_NAME` | yes | Legal or trading name shown by the processor |
| `PAY_BUSINESS_ADDRESS` | yes | Business address |
| `PAY_SUPPORT_EMAIL` | yes | Support contact |
| `BT_BILLING_ENABLED` | yes | Master switch (`true` to enable) |
| `BT_BILLING_DEFAULT_CURRENCY` | no | Preselects the currency when creating a plan |
| `BT_BILLING_DEFAULT_COUNTRY` | by feature | Used when an owner has no country (merchant onboarding) |
| `PAY_APPLICATION_NAME` | no | Defaults to `Community Engine` |

`BetterTogether::Billing.enabled?(platform)` is true only when the flag is on, the identity is configured, and a registered processor has a **context** for that platform. Today only the host platform has one, so billing is off for every other platform. See [platform_isolation.md](platform_isolation.md).

## Writing an adapter

Subclass `BetterTogether::Billing::ProcessorAdapter` and register it from your engine:

```ruby
initializer 'my_processor.register' do
  BetterTogether::Billing.register_processor(:my_processor, -> { MyProcessor::Adapter.new })
end
```

Implement `processor_name` (it must equal the name you register under; a mismatch raises `ContractError`), `sanitize_payload`, `capabilities`, `webhook_event_types`, and the methods for each capability you advertise. Every capability method receives `context:`, a `BetterTogether::Billing::ProcessorContext` naming the platform and processor account the call is for; use it instead of reading global environment variables, so one platform never acts through another's account. `ProcessorAdapter::CAPABILITY_METHODS` lists the methods and keywords per capability. The contract version is checked when the adapter is built; a mismatch raises `ContractError`. Run the shared examples in `spec/support/shared_examples/billing_processor_adapter.rb` against your adapter.

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
