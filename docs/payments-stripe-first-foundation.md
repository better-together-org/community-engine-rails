# Community Engine Payments: Stripe-First Foundation

Community Engine now includes a Stripe-first billing slice built around `pay`, `BetterTogether::Community` as the billable owner, and BTS-local billing records for plans, subscriptions, and event audit trails.

## Scope

This implementation includes:

- `pay` and `stripe` gem dependencies
- guarded Pay migrations for host apps with partial schema state
- `BetterTogether::Community` as the billable Stripe customer owner
- community-admin billing page with hosted checkout and billing portal links
- local billing plan, subscription, and event models
- Stripe webhook processing that enqueues narrow subscription events, persists BTS billing events, and syncs local subscription state

This implementation does not yet include:

- dunning and failed-payment recovery UX
- automated plan seeding
- tax, invoicing, or metered-billing flows

## Architecture

```mermaid
flowchart LR
  Admin[Community Admin] --> BillingUI[Community Billing Page]
  BillingUI --> Checkout[Stripe Checkout]
  BillingUI --> Portal[Stripe Billing Portal]
  Checkout --> Stripe[Stripe]
  Portal --> Stripe
  Stripe -->|webhooks| PayWebhook[/pay/webhooks/stripe]
  PayWebhook --> PayGem[Pay webhook delegator]
  PayGem --> Job[ProcessStripeEventJob]
  Job --> Processor[StripeEventProcessor]
  Processor --> EventLog[(better_together_billing_events)]
  Processor --> LocalSubs[(better_together_billing_subscriptions)]
  Processor --> Plans[(better_together_billing_plans)]
  Processor --> Communities[(better_together_communities)]
```

## Billing Model

- `BetterTogether::Billing::Plan` is the local catalog record and references the canonical Stripe Price ID.
- `BetterTogether::Billing::Subscription` is the CE-local subscription read model.
- `BetterTogether::Billing::Event` stores raw Stripe webhook payloads plus BTS processing state.
- `Pay::Customer` remains the processor-facing customer record owned by `BetterTogether::Community`.

## Why `Community` Is Billable

The first release treats the community as the billable organization boundary. That keeps billing tied to the administrative unit that receives hosted platform value, support, and subscription status.

## Source Docs

- [Stripe setup and install guide](./payments-stripe-first-setup.md)
- [Webhook operations and resilience guide](./payments-stripe-webhook-operations.md)
