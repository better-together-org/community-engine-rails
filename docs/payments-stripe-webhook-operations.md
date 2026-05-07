# Stripe Webhook Operations

This guide describes the current webhook path and the operational gaps that still need hardening before production rollout.

## Current Flow

```mermaid
sequenceDiagram
  participant Stripe
  participant Pay as Pay Webhook Endpoint
  participant Job as ProcessStripeEventJob
  participant Processor as StripeEventProcessor
  participant EventLog as Billing Event Log
  participant Subs as Local Subscription Table

  Stripe->>Pay: customer.subscription.*
  Pay->>Job: enqueue payload
  Job->>Processor: reconstruct Stripe event and process
  Processor->>EventLog: upsert event payload and processing state
  Processor->>Subs: create or update subscription snapshot
```

## Processing Contract

- every webhook event is keyed by Stripe `event.id`
- only the Stripe subscription events CE currently uses are subscribed
- the custom CE sync work is enqueued off the webhook request thread
- checkout success redirects also perform an idempotent CE-side sync using the Checkout Session ID
- subscription events attempt to resolve the community from Stripe metadata first, then `Pay::Customer`
- unsupported or unresolvable events are marked as ignored instead of failing silently
- local subscriptions now record sync source, last sync timestamp, and the most recent Stripe event or Checkout Session reference

## Required Operational Expectations

- webhook signing must remain enabled with `STRIPE_WEBHOOK_SECRET`
- event replay must be safe because the event table keys on processor plus event id
- Stripe delivery retries must not produce duplicate local subscription rows
- local plans must continue to reference stable Stripe Price IDs

## Known Gaps Before Production Hardening

- there is no dead-letter or retry queue for local sync failures
- invoice, payment failure, and charge dispute events are not yet surfaced in CE UX
- subscription reconciliation is event-driven only and does not yet include a scheduled backfill job

## Recommended Next Hardening Steps

1. Move the processor call into an idempotent Active Job with a narrow synchronous ack path.
2. Add invoice, payment failure, and dispute processors before enabling production self-service access decisions.
3. Extend reconciliation so unresolved drift is flagged explicitly for operators, not just resynchronized when possible.
4. Capture more processor state for operational support, including last invoice id and last event creation time.
5. Add admin-visible error states for failed syncs and portal unavailability.
6. Add alerting on repeated webhook processing failures.
