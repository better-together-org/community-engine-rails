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

## Settlement kinds: remote, manual and internal

Not every way of paying goes through a payment vendor. An adapter says how money reaches the seller with `settlement_kind`, and the contract treats the three kinds differently.

| Kind | Examples | Who knows the payment happened |
|---|---|---|
| `remote` (default) | Stripe, Braintree | The processor, by webhook |
| `manual` | cash, cheque, e-transfer | The seller, who confirms receipt. Core owns the state machine; the adapter only describes the method |
| `internal` | store credit | A ledger inside Community Engine |

A manual adapter advertises the `offline_settlement` capability (and only a manual adapter may). `verify!` rejects the mismatch. Manual adapters also declare:

- `recurring_mode`: `automatic` (the processor renews), `manual` (each period is a new pending payment the seller confirms) or `none`. Manual methods are `manual`.
- `supported_countries`: ISO 3166 alpha-2 codes, or `nil` for anywhere (e-transfer is `['CA']`). Core hides the method or refuses to enable it outside them.
- `fee_collectible?`: false for every manual method, because the platform can neither track nor take a fee on a payment made outside it. Reports show such sales as uncollected rather than zero.
- `instruction_fields`: the `Billing::InstructionField`s a seller fills in so buyers know how to pay (a payee name, an e-transfer address). Values are stored encrypted and shown only on the buyer's own order.
- `instructions_for(context:, setting:, order:)`: what the buyer is shown. It must never be logged or put in an email.

The contract also gains two capabilities used by every payment kind: `refunds` (`refund`) and `transfers` (`transfer`, for paying a seller out). Both carry `context:` and an `idempotency_key`.
