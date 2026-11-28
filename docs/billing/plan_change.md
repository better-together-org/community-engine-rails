# Billing Plan Change

A payer can move a subscription that Community Engine renews to another recurring price of the platform (another plan's, or the same plan's other interval), and chooses **when** the change happens.

## Behaviour

- On the subscription page, "Change plan" lists every other active recurring paid price of the platform's listed plans in the same currency, with the plan the subscriber is on first (its other intervals are offered even if it is no longer listed). A move **now** also needs the same interval and count.
- The payer picks **from my next period** or **now**.

### From the next period

- `pending_price` (and its plan, `pending_plan`) is saved on the subscription term. Nothing else changes: the current period, price and access stay as they are, and the choice can be taken back.
- When the next period is made (`Subscriptions::GenerateRenewal`), `Subscriptions::ChangePlan.apply` makes the chosen price the term's price, and its plan the term's plan, moves the entitlement to it and re-syncs what it includes. The next invoice is for the new plan. Purchase agreements the new plan needs are asked for the usual way (the period waits as `needs_agreement`).
- No money moves when the request is made.

### Now, prorated

The rest of the paid period is prorated by the time left: `(new price - price sold at) x time left / period length`, using the subscription's current period.

- **Dearer plan.** An invoice for the difference is made (taxed like a renewal, an ordinary order for the payer, with its own line for the new plan). The subscriber keeps the plan they have, and the term remembers the invoice in `pending_plan_order`. When the invoice is paid, `Subscriptions::OrderPaid` calls `ChangePlan.paid`, which changes the plan and re-syncs the entitlement. Withdrawing the change cancels the unpaid invoice.
- **Cheaper plan.** The plan changes at once and the difference is granted back as store credit (origin `adjustment`, keyed by subscription, period and plan so repeating it grants nothing twice).
- **Same price.** The plan changes at once and nothing is charged.

After a change, the next invoice is for the new plan at its price.

## Downgrade guard

A move is refused while what the holder uses of a quota (storage, AI tokens) is above what the limit would be on the new plan. Usage is never reduced.

## Not covered

A switch of interval now (prorated across different period lengths) is not offered; it takes effect from the next period, and the periods then count from the end of the current one. Subscriptions renewed by a payment vendor are not covered.
