# Billing Plan Change

A payer can move a subscription that Community Engine renews to another of the platform's plans. The move takes effect when the next period starts.

## Behaviour

- On the subscription page, "Change plan" lists the platform's other active, listed, paid plans on the same schedule (interval, interval count) and currency.
- Choosing one saves `pending_plan` on the subscription term. Nothing else changes: the current period, price and access stay as they are, and the choice can be taken back.
- When the next period is made (`Subscriptions::GenerateRenewal`), `Subscriptions::ChangePlan.apply` makes the chosen plan the term's plan at its price, moves the entitlement to it and re-syncs what it includes. The next invoice is for the new plan. Purchase agreements the new plan needs are asked for the usual way (the period waits as `needs_agreement`).
- No money moves when the request is made, so there is no proration. Credit for unused time is not given.

## Downgrade guard

A move is refused while what the holder uses of a quota (storage, AI tokens) is above what the limit would be on the new plan. Usage is never reduced.

## Not covered

Moves between schedules (monthly to yearly), immediate changes with proration, and subscriptions renewed by a payment vendor.
