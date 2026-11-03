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

**Capabilities.** `checkout`, `portal`, `plan_sync`, `lookups`, `refunds` and `offline_settlement` are used by core. `merchant_accounts` and `transfers` are **reserved**: the contract names them but core has no caller until payouts exist. There is no stored-value capability: store credit is a ledger inside Community Engine, and Pay only mirrors Stripe's customer balance read-only. A `checkout` adapter implements `create_checkout_session` (returns a `CheckoutSession`), `sync_checkout_session`, `release_payment` (expire the session or cancel the intent when core lets the order go), `reconcile_payment` (pull the processor's state; never trust a payload alone), `payment_action_url` and `receipt_url` (an https URL or nil); `refund` returns a `RefundResult` whose `reference` becomes the refund's `processor_reference`. Nothing is versioned or shimmed: the contract is simply this.

`process_event` should **pull state itself** (`Charge.sync`, `Pay.sync`) and return `retry` if Pay's mirror is not there yet, rather than trusting Pay's own handler to have run: a Pay handler returns silently when its customer is missing and Pay then deletes the delivery. Keep `Billing::Event.payload` to ids and the platform reference; Pay already holds the personal data.

Core owns idempotency keys and money state. Money-moving calls always receive an `idempotency_key` that the adapter must pass through to the processor.

**Wrap Pay for state and reads; call the processor's SDK for writes.** Pay is the right tool for the customer (`api_record`), for syncing charges and subscriptions (`Charge.sync`, `Subscription.sync`, `Pay.sync`) and for everything it mirrors. But Pay's write helpers (`Customer#checkout`, `#subscribe`, `Charge#refund!`, `Merchant#transfer`) pass only the connected account as a request option: they cannot carry a request-level idempotency key, and a key passed as a parameter would be rejected. So an adapter creates Checkout sessions, refunds and transfers with the SDK directly, with `{ idempotency_key:, stripe_account: }`, and then lets Pay sync the result. Never run `pay:install:migrations`: our Pay tables are ported by hand into the engine's migrations, and a spec fails if Pay ships a migration we have not ported.

## Settlement kinds: remote, manual and internal

Not every way of paying goes through a payment vendor. An adapter says how money reaches the seller with `settlement_kind`, and the contract treats the three kinds differently.

| Kind | Examples | Who knows the payment happened |
|---|---|---|
| `remote` (default) | Stripe, Braintree | The processor, by webhook |
| `manual` | cash, cheque, e-transfer | The seller, who confirms receipt. Core owns the state machine; the adapter only describes the method |
| `internal` | store credit | A ledger inside Community Engine |

`Billing.local_method?` is true for `manual` and `internal`, `Billing.manual_method?` only for `manual` and `Billing.internal_method?` only for `internal`; ask the narrowest question you mean, because instructions, acknowledgements and a seller's confirmation exist only for manual methods. An internal adapter (`InternalProcessorAdapter`) advertises no capability, has no webhooks and no instructions, and `ProcessorAdapter` gives `grant_on_options`, `default_grant_on` and `settings_errors` safe defaults so a setting never calls a manual-only method on it. See [store_credit.md](store_credit.md).

A manual adapter advertises the `offline_settlement` capability (and only a manual adapter may). `verify!` rejects the mismatch. Manual adapters also declare:

- `recurring_mode`: `automatic` (the processor renews), `manual` (each period is a new pending payment the seller confirms) or `none`. Manual methods are `manual`.
- `supported_countries`: ISO 3166 alpha-2 codes, or `nil` for anywhere (e-transfer is `['CA']`). Core hides the method or refuses to enable it outside them.
- `fee_collectible?`: false for every manual method, because the platform can neither track nor take a fee on a payment made outside it. Reports show such sales as uncollected rather than zero.
- `instruction_fields`: the `Billing::InstructionField`s a seller fills in so buyers know how to pay (a payee name, an e-transfer address). Values are stored encrypted and shown only on the buyer's own order.
- `instructions_for(context:, setting:, order:)`: what the buyer is shown. It must never be logged or put in an email.

The contract also gains two capabilities used by every payment kind: `refunds` (`refund`) and `transfers` (`transfer`, for paying a seller out). Both carry `context:` and an `idempotency_key`.

## Event pipeline

Processors deliver webhooks through Pay. Core logs, attributes, retries and replays them; the adapter only understands the vendor payload.

1. After boot, core subscribes each registered adapter's `webhook_event_types` to Pay's delegator. A processor whose adapter cannot be built is logged and reported and skipped; it never stops the application booting.
2. `adapter.normalize_webhook(vendor_event)` returns `{ event_id:, event_type:, payload: }`, and may add `occurred_at:` (when the processor says it happened), `platform_id:` and `account_ref:`.
3. Core attributes the event to **one platform** (below) and records it once per `(processor, event_id)` in `better_together_billing_events`. The payload and error text are encrypted at rest ([encryption.md](encryption.md)).
4. `ProcessBillingEventJob` is enqueued with the **event id only**, so payloads never appear in Redis or job logs. It runs on the `billing` queue ([queue rollout](../production/billing_queue_rollout.md)).
5. `adapter.process_event(event:, context:)` reads `event.payload` and returns a `Billing::EventResult`: `processed`, `ignored`, `alerted` (handled, but an operator should look), or `retry` (a prerequisite such as a not-yet-synced subscription is missing). `context` is the platform and processor account the event belongs to.

Status values: `pending`, `processed`, `ignored`, `alerted`, `failed`, `dead_lettered`, `replayed`. Only `failed` and `dead_lettered` count as problems, so unrelated or informational events do not raise alerts.

### Which platform an event belongs to

Nothing is guessed. An event is attributed, in order, by the `platform_id:` the adapter reports, by the `account_ref:` matched to a platform whose context names that account, or, with neither, to the only platform that has billing configured for the processor. An event from a processor account that no context names (a Connect account nobody configured) is refused, not handed to the host. If the adapter also reports a `customer_ref:` and a Pay customer with that id lives on a **different** platform than the one resolved, the event is refused too: Pay's own handlers attribute by customer, and the two logs must not disagree. If that does not single out one platform (none, or several), no tenant row is created: the dispatcher reports the error and raises `Billing::UnattributableWebhookError`. Pay deletes a webhook row only after successful processing, so the delivery stays, encrypted, and an operator can replay it after fixing the mapping. Pay's job discards the error (retrying cannot change the answer), including when Rails wraps it with another subscriber's failure in one `InstrumentationSubscriberError`. Replay a kept delivery with `rake better_together:billing:pay_webhooks` (list) and `rake "better_together:billing:reprocess_pay_webhook[ID]"`; this runs Pay's own handlers again as well, which are written to be repeated.

**One platform key.** Pay uses one global `Stripe.api_key` and one webhook signing secret, and its own handlers call Stripe before looking anything up locally. The environment context (the host platform) therefore uses Pay's global credentials. Other platforms are served through Stripe Connect, with the connected account in `account_ref` (Pay's `stripe_account`); separate API keys per platform are not supported through Pay. Set `STRIPE_WEBHOOK_RECEIVE_TEST_EVENTS=false` in production: Pay accepts test-mode events by default.

A duplicate delivery that matches an event already logged for a **different** platform is refused (`EventIngest::PlatformConflictError`), because vendor event ids are globally unique.

### What Pay handles, and what an adapter must subscribe to itself

Pay's controllers drop any event nobody subscribed to, and subscription matches by **prefix**, so `webhook_event_types` is also Pay's ingestion allow-list (`"stripe.charge.dispute"` covers its sub-events). Pay's own Stripe handlers keep its tables in step for: `charge.succeeded/updated/refunded`, `payment_intent.succeeded`, `invoice.upcoming/updated/payment_action_required/payment_failed`, `customer.subscription.created/updated/deleted/trial_will_end`, `customer.updated/deleted`, `payment_method.*`, `account.updated`, `checkout.session.completed/async_payment_succeeded`.

Pay does **not** handle, so an adapter that cares must subscribe and must sync Pay's tables itself (a Pay handler returns silently when its customer is missing, then Pay deletes the delivery): `invoice.paid`, `invoice.payment_succeeded`, `charge.failed`, `payment_intent.payment_failed`, `charge.dispute.*`, `charge.refund.updated`/`refund.*`, `customer.subscription.paused/resumed`, `checkout.session.expired` and `async_payment_failed`.

Rules the adapters replicate from Pay's handlers, because Pay's mail is off: `payment_failed` and `payment_action_required` are skipped for `incomplete` subscriptions (a first payment is handled by Checkout); `subscription_renewing` is for yearly plans with a next payment attempt; there is no "trial ended" event of its own (it is `trial_will_end` arriving after the end, so also watch `customer.subscription.updated` for trialing leaving trial). A `Pay::Webhook` reaches `normalize_webhook` as the processor's object, not a Hash: a `::Stripe::Event` for Stripe, only the event's `data` for Paddle Billing (no event id), a notification object for Braintree.

### What an outcome says happened

`Billing::EventResult` carries two optional, processor-neutral fields so the rest of the system never reads a vendor's event names:

- `outcome_kind`, one of `EventResult::OUTCOME_KINDS`. Processor adapters report `payment_succeeded`, `payment_failed`, `payment_action_required`, `refund_issued`, `dispute_opened`, `dispute_resolved`, `subscription_renewing`, `subscription_canceled`, `trial_ending` and `trial_ended` (the first seven are what Pay's own mailers send: receipt, refund, renewing, action required, failed payment, trial will end, trial ended; the dispute kinds and `subscription_canceled` are ours). Core's own services report `payment_claimed`, `payment_confirmed`, `payment_rejected`, `payment_expired` and `refund_recorded` for manual methods such as cash, cheque and e-transfer, which log events named `<method>.payment_claimed`, `<method>.payment_confirmed` and so on. An unknown kind raises, so a vendor name cannot leak in.
- `subject`: the record the event is about (an order, a Joatu agreement, a hosted platform). Only models that include `Billing::Subjectable` are accepted, the same opt-in idea as `Billable` for owners, and a platform-bound subject must be on the event's platform.

The processor stores both on the event (`outcome_kind`, `subject`), so notifications, reports and the operator queue read them from there.

### Writing `process_event`

It **must be idempotent**. A job that fails after the adapter acted is retried, a duplicate delivery of a still-pending event is enqueued again, and a replay runs the event again. Use the event id (and, for a processor write, a key derived from it) so repeating it is harmless. Core helps but does not remove the need:

- an event whose outcome is already final (`processed`, `ignored`, `alerted`) is skipped;
- a job takes a short lease (`claimed_at`, ten minutes) under a row lock before calling the adapter, so two jobs never run the processor at once; a lease left by a crashed worker expires;
- the outcome is written under a row lock, so a sweep or replay that touched the row meanwhile cannot make the write fail, and a late success clears any dead-letter state;
- a failure to record the outcome (for example an owner type that is not billable) is itself recorded as a failure, not left silently pending.

### Retries, dead letters and replay

- A failed result is retried by ActiveJob up to `Billing::Event::MAX_ATTEMPTS` (5) times with growing waits. A `retry` result waits 30 seconds, 2 minutes, 10 minutes, then 30 minutes (about forty minutes in all), because the prerequisite it waits for (Pay's own sync, say) can lag. `processed_at` is set only on a final outcome.
- Hourly, `DeadLetterStaleBillingEventsJob` moves events that exhausted their retries (`retries_exhausted`) or made no progress for 6 hours (`stale_unresolved_drift`) to `dead_lettered`. It handles one event at a time under a row lock that re-checks the event is still stuck, so an event a job finished meanwhile is left alone, and one bad row does not stop the sweep.
- A duplicate delivery of an event that is still `pending` is enqueued again, in case the first enqueue was lost.
- `Billing::ReplayEvent` resets the attempt count and re-enqueues a dead-lettered event. It refuses events whose payload was redacted, whose processor is no longer installed, or whose platform no longer has billing configured for the processor.
- `occurred_at` is stored as `processor_event_created_at`. Receive time is not event time, so an adapter that must ignore a stale event compares this value.

### Payload retention

Raw payloads are kept for `BT_BILLING_EVENT_PAYLOAD_RETENTION_DAYS` (default 30) after processing. A daily job then replaces each with `adapter.sanitize_payload(payload)`. Redaction fails closed: if the adapter is gone, cannot be built, raises, or returns something that is not a Hash, the payload is replaced with just `id` and `type`, so a broken adapter never leaves a raw payload behind. Sanitizers must remove personal data and secrets.

Pay keeps the raw delivery in `pay_webhooks` until it is processed. A daily job (`PruneStalePayWebhooksJob`) deletes deliveries that are still there after the same retention window.

## Diagram

```mermaid
flowchart TD
  W[Processor webhook<br/>POST /pay/webhooks/:processor] --> P[Pay verifies the signature<br/>and stores the delivery, encrypted]
  P --> PJ[Pay::Webhooks::ProcessJob<br/>billing queue]
  PJ --> D[WebhookDispatcher<br/>adapter.normalize_webhook]
  D --> A{One platform with billing<br/>configured owns the event?}
  A -->|No| U[Report the error and raise<br/>UnattributableWebhookError<br/>nothing stored for any tenant]
  U --> K[Pay keeps the delivery<br/>for operator replay]
  K --> PR[PruneStalePayWebhooksJob<br/>after the retention window]
  A -->|Yes| I[EventIngest<br/>once per processor and event id]
  I --> X{Already logged for<br/>a different platform?}
  X -->|Yes| C[PlatformConflictError]
  X -->|No| L[Billing event: pending<br/>payload encrypted]
  L --> Q[ProcessBillingEventJob<br/>event id only, billing queue]
  Q --> T{Outcome already final?}
  T -->|Yes| S[Skip]
  T -->|No| CL[Take the lease under a row lock]
  CL --> R[adapter.process_event<br/>with the platform context]
  R --> O{Result}
  O -->|processed, ignored, alerted| F[Final outcome<br/>clears any dead-letter state]
  O -->|retry| RT[pending, wait 30s, 2m, 10m, 30m]
  RT --> Q
  O -->|error| FL[failed, up to 5 attempts]
  FL --> Q
  FL --> DL[Hourly sweep:<br/>dead_lettered after 5 attempts or 6 hours]
  RT --> DL
  DL --> RP[ReplayEvent resets attempts<br/>and enqueues again]
  RP --> Q
  F --> RD[Daily redaction after retention<br/>sanitizer, or id and type only]
```

**Diagram Files:**
- [Mermaid source](../diagrams/source/billing_event_pipeline_flow.mmd) - editable source
- [PNG export](../diagrams/exports/png/billing_event_pipeline_flow.png) - high-resolution image
- [SVG export](../diagrams/exports/svg/billing_event_pipeline_flow.svg) - vector graphics

## Plan catalog

Plans, and the processor-backed fields of the plan form (async option lists, fields the
processor only accepts at creation, creating and editing products and prices from
Community Engine) are described in [plan_catalog.md](plan_catalog.md).
