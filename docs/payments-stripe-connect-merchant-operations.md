# Stripe Connect Merchant Account Operations

This runbook covers the current operator-facing Stripe Connect merchant flow in Community Engine.

## Scope

The current Phase 2 merchant slice supports:

- person-owned Stripe Connect merchant accounts
- community-owned Stripe Connect merchant accounts
- owner-facing onboarding entry points from the existing billing pages
- manual refresh of one connected merchant account
- webhook-driven merchant reconciliation for:
  - `account.updated`
  - `account.application.deauthorized`

This runbook does not yet cover customer-facing commerce charges, refunds, transfers, or payout reporting.

## Core Model Boundaries

Keep these concepts separate during support and operator work:

1. `billable_owner`
   The CE entity paying BTS for hosted service.
2. `beneficiary`
   The CE entity receiving hosted service or entitlement.
3. `merchant_owner`
   The CE entity that owns a connected Stripe merchant account.

Do not assume that a hosted subscription implies a merchant account, or that a merchant account implies hosted billing ownership.

## Current Operator Surfaces

Merchant operators currently work from the existing billing pages:

- person billing page
- community billing page

Those pages expose:

- merchant provider
- merchant status
- `charges_enabled`
- `payouts_enabled`
- onboarding action
- refresh action

## Expected Merchant Status Meanings

- `pending`
  Local record exists, but onboarding or capability activation is incomplete.
- `onboarding`
  Operator is still expected to complete Stripe onboarding.
- `required_action`
  Stripe requires more information or compliance follow-up.
- `active`
  Charges and payouts are ready for downstream commerce use.
- `restricted`
  The account exists but Stripe has limited capabilities or blocked normal use.
- `disabled`
  The account is locally known but not currently usable.
- `errored`
  CE could not reconcile the account cleanly.
- `disconnected`
  CE no longer has an active Stripe Connect authorization for the account.

## Onboarding Runbook

### When to use

- a person or community wants to connect Stripe for future commerce flows
- a merchant card shows no connected account or onboarding is incomplete

### Operator steps

1. Open the owner billing page.
2. Confirm the actor has merchant-account management authority.
3. Start the merchant onboarding action.
4. Complete Stripe onboarding.
5. Return to CE and verify the merchant card reflects the updated state.
6. If the status still looks stale, run the refresh action.

### Expected result

- CE either reuses the existing connected Stripe account or provisions the onboarding flow for a new one
- the merchant card shows the latest status and enabled capabilities

## Capability Loss Runbook

### Symptoms

- `charges_enabled = false`
- `payouts_enabled = false`
- merchant status becomes `required_action`, `restricted`, or `disabled`
- operator reports that onboarding is complete but commerce should not proceed

### Operator steps

1. Refresh the merchant account from the billing page.
2. Check whether CE still shows a restricted or required-action state.
3. If CE still shows restricted state, inspect the merchant metadata snapshot and Stripe dashboard for missing requirements.
4. Do not treat hosted billing status as evidence that commerce is available.

### Expected result

- CE reflects the latest Stripe capability state
- support can distinguish between stale local state and a genuine Stripe compliance restriction

## Reconciliation Runbook

### Automatic paths

- Stripe webhooks are journaled in `BetterTogether::Billing::Event`
- `StripeEventProcessor` handles `account.updated`
- `StripeEventProcessor` handles `account.application.deauthorized`

### Manual paths

- owner-facing refresh action from the billing page
- `BetterTogether::Billing::ReconcileStripeMerchantAccountJob` for one connected merchant account

### When to run manual reconciliation

- the merchant card looks stale after onboarding
- support suspects a missed or delayed webhook
- CE and Stripe dashboard state do not match

## Disconnect / Deauthorization Runbook

### Trigger

- Stripe sends `account.application.deauthorized`

### CE behavior

CE marks the local merchant account:

- `status = disconnected`
- `charges_enabled = false`
- `payouts_enabled = false`

Webhook metadata is retained so support can confirm that the disconnect came from deauthorization rather than a normal capability restriction.

### Operator response

1. Confirm the merchant card shows `disconnected`.
2. Do not assume that hosted subscription ownership changed.
3. If the operator still intends to use Stripe Connect, restart onboarding from the billing page.

## Support Rules

- Treat merchant health as distinct from hosted billing health.
- Use merchant refresh before concluding that local state is wrong.
- Use webhook history plus merchant metadata to distinguish:
  - stale local state
  - Stripe restriction
  - explicit deauthorization
- Do not expose raw Stripe payloads in operator UI.

## Current Gaps

- no scheduled fleet-wide merchant reconciliation scan yet
- no operator-visible dead-letter or repeated-failure alerting yet
- no customer-facing commerce ledger yet
- no payout-history or transfer reporting yet
