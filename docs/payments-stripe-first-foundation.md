# Community Engine Payments: Stripe-First Foundation

Community Engine now includes a Stripe-first billing slice built around `pay`, `BetterTogether::Community` as the billable owner, and BTS-local billing records for plans, subscriptions, and event audit trails.

## Scope

This implementation includes:

- `pay` and `stripe` gem dependencies
- guarded Pay migrations for host apps with partial schema state
- `BetterTogether::Community` as the billable Stripe customer owner
- community-admin billing page with hosted checkout and billing portal links
- local billing plan, subscription, and event models with sync tracking
- a CE-owned checkout return path that can synchronize Stripe checkout completion immediately
- Stripe webhook processing that enqueues narrow subscription events, persists BTS billing events, and syncs local subscription state
- a manual and job-driven community reconciliation path for Stripe subscriptions

This implementation does not yet include:

- dunning and failed-payment recovery UX
- automated plan seeding
- tax, invoicing, or metered-billing flows
- automated remediation for unresolved reconciliation mismatches

## Architecture

```mermaid
flowchart LR
  Admin[Community Admin] --> BillingUI[Community Billing Page]
  BillingUI --> Checkout[Stripe Checkout]
  BillingUI --> Portal[Stripe Billing Portal]
  Checkout --> Stripe[Stripe]
  Portal --> Stripe
  Stripe -->|webhooks| PayWebhook[/pay/webhooks/stripe]
  Stripe -->|redirect with session id| ReturnFlow[Community Billing Return Flow]
  PayWebhook --> PayGem[Pay webhook delegator]
  PayGem --> Job[ProcessStripeEventJob]
  Job --> Processor[StripeEventProcessor]
  ReturnFlow --> CheckoutSync[StripeCheckoutSessionSync]
  CheckoutSync --> SubSync[StripeSubscriptionSync]
  ReconcileJob[ReconcileStripeCommunityBillingJob] --> Reconciler[StripeCommunityReconciliation]
  Reconciler --> SubSync
  Processor --> EventLog[(better_together_billing_events)]
  Processor --> LocalSubs[(better_together_billing_subscriptions)]
  Processor --> Plans[(better_together_billing_plans)]
  Processor --> Communities[(better_together_communities)]
  SubSync --> LocalSubs
```

## Stakeholders

The current billing slice affects operators and organization-level owners first, not individual end users.

```mermaid
flowchart TD
  PM[Platform Manager]
  CA[Community Admin]
  Support[BTS Support and Finance]
  Community[Billable Community]
  Platform[Primary Platform]
  Members[Community Members]

  PM --> CA
  CA --> Community
  Community --> Platform
  Community --> Support
  Platform --> Members
  Support --> Community
```

- `Community Admin` and `Platform Manager` are the direct human operators of billing.
- `Community` is the billable owner and the main operational subject of reconciliation and subscription state.
- `Primary Platform` is operationally affected, but it is not the processor-facing customer in this release.
- `Community Members` are indirect stakeholders because billing can affect the hosted space they use.
- `BTS Support and Finance` rely on the local billing records and event trail for audit, support, and reconciliation.

## Billing Model

- `BetterTogether::Billing::Plan` is the local catalog record and references the canonical Stripe Price ID.
- `BetterTogether::Billing::Subscription` is the CE-local subscription read model.
- `BetterTogether::Billing::Event` stores raw Stripe webhook payloads plus BTS processing state.
- `Pay::Customer` remains the processor-facing customer record owned by `BetterTogether::Community`.

## Ownership Wiring

```mermaid
flowchart LR
  Person[Person]
  Community[BetterTogether::Community]
  Platform[BetterTogether::Platform]
  PayCustomer[Pay::Customer]
  StripeCustomer[Stripe Customer]
  LocalSub[Billing Subscription]

  Person -->|administers or creates| Community
  Community -->|has_one| Platform
  Community -->|pay_customer| PayCustomer
  PayCustomer --> StripeCustomer
  StripeCustomer -->|metadata and processor id| Community
  StripeCustomer --> LocalSub
  Community --> LocalSub
```

- people are currently actors and contacts, not billable owners
- communities are the organization boundary that own Stripe customer state
- platforms hang off communities and inherit the operational consequences of billing
- local billing subscriptions are CE-side read models tied back to the community

## Why `Community` Is Billable

The first release treats the community as the billable organization boundary. That keeps billing tied to the administrative unit that receives hosted platform value, support, and subscription status.

## Source Docs

- [Stripe setup and install guide](./payments-stripe-first-setup.md)
- [Webhook operations and resilience guide](./payments-stripe-webhook-operations.md)
