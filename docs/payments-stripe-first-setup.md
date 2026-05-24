# Stripe-First Billing Setup

This guide covers the minimum configuration required to run the current Community Engine billing slice with Stripe and `pay`.

## Prerequisites

- Stripe account with Billing enabled
- products and recurring prices created in Stripe
- Community Engine app with the new billing migrations applied
- a background job backend ready for follow-up work, even though the current webhook sync is inline

## Application Configuration

Set the standard `pay` and Stripe credentials in the host app environment:

- `STRIPE_PUBLIC_KEY`
- `STRIPE_PRIVATE_KEY`
- `STRIPE_SIGNING_SECRET`

If the host app uses Rails encrypted credentials instead of plain environment variables, map the same values into the initializer path expected by `pay`.

## Queueing Requirement

Community Engine now enqueues CE-specific Stripe synchronization work in Active Job. Production rollout requires:

- a persistent Active Job backend
- running workers for the queue used by billing jobs
- alerting on repeated job failures

Without that, webhook acknowledgement remains functional, but CE-side synchronization becomes less resilient than intended.

## Database Preparation

Run the engine migrations in the host app:

```bash
bin/rails db:migrate
```

The bundled Pay migrations in this branch are guarded for partial-schema upgrade states. They use `table_exists?`, `column_exists?`, and `index_exists?` checks so release-branch adopters can apply them safely on hosts with drifted billing tables.

## Seed Billing Plans

Create at least one `BetterTogether::Billing::Plan` record per Stripe Price ID before exposing the billing page. Each plan needs:

- `identifier`
- `name`
- `stripe_price_id`
- `amount_cents`
- `currency`
- `billing_interval`
- `active`

For the current hosted-billing launch path:

- prefer recurring Stripe Prices only
- do not expose `one_time` plans on the billing pages until CE handles the full Stripe one-time fulfillment path
- add participant-facing metadata where possible:
  - `participant_summary`
  - `participant_benefits`
  - `beneficiary_label`
- add hosted-entitlement metadata where useful:
  - `hosted_access_level`
  - `support_tier`
  - `community_capacity_tier`

The local record is the CE-side catalog. Stripe remains the source of truth for charge execution.

## Stripe Dashboard Configuration

Create or confirm:

- a Product for each CE offer
- a Price for each billable interval
- Billing Portal enabled for customer self-service
- webhook endpoint pointing to `https://<host>/pay/webhooks/stripe`

Subscribe the webhook endpoint to at least:

- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`

Additional invoice and payment-intent events can be added later when CE begins surfacing failed payments and receipts.

## Local Validation

Recommended checks:

```bash
bin/dc-run bundle exec rails zeitwerk:check
bin/dc-run bundle exec rubocop --parallel
bin/dc-run ./bin/i18n health
bin/dc-run bundle exec rspec spec/requests/better_together/community_billings_spec.rb spec/services/better_together/billing/stripe_event_processor_spec.rb
```

## Admin UX Entry Point

Community admins reach billing from the community edit surface. The billing page then supports:

- hosted Stripe checkout for a selected local plan
- immediate checkout return synchronization using `checkout_session_id`
- Stripe Billing Portal redirect
- manual reconciliation trigger for the community's Stripe customer
- read-only display of the latest synced local subscription state
