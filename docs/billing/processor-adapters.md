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
