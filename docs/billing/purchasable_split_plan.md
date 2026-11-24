# Splitting one-off purchases out of Plan: remediation plan

Status: proposed 2026-11-24 against `feature/billing` at `920635b8a`. Nothing here is decided until the project owner approves it.

## The problem in one paragraph

A plan should mean something a person subscribes to and that renews. Today `Billing::Plan` is also the only thing an order line can be for, so
one-off purchases are forced into it: a one-time plan (`billing_interval: 'one_time'`) and an add-on (`add_on: true`). The model then carries
renewal settings that one-off items ignore, and the order engine decides what to do after payment by asking "is this a plan, and does it recur?".
Quota top-ups, one-time add-ons, donations and event tickets all need a purchasable that is not a plan.

## What is mixed together inside Plan today

Plan is one table and one class holding six separate concerns:

1. **Catalog identity.** Seller, identifier, translated name, description and benefits, listing, restriction to members or subscribers, tax category,
   agreement targeting. Every sellable thing needs this.
2. **Price.** Amount, currency, interval, interval count. Every sellable thing needs a price, but only subscriptions need an interval.
3. **Processor mirror.** Product id, price id, sync status, lock rules after linking, the sync job and idempotency key. Every thing sold through an
   online processor needs this.
4. **Subscription terms.** Grace days, renewal lead days, plan change, pending plan, hosted tier metadata. Only recurring plans need these.
5. **What it gives.** Plan grants (role, feature access, quota allowance) and the entitlements built from them. Subscriptions and one-off items both
   give things, but with different lifetimes.
6. **Add-on wiring.** The `add_on` flag, `plan_add_ons` links, and rules such as "an add-on cannot have grants" and "an add-on cannot renew".
   The second rule shows the add-on is already a different kind of thing forced into the plan shape.

## Where the plan assumption leaks (the seams)

These are the places that must change. Counts are files under `app` and `lib` that mention the term.

- **The order engine.** `Orders::Settle#follow_up_entitlement` checks `purchasable.is_a?(Plan) && !recurring?`. `Checkout::Methods#purpose` is
  `plan.recurring? ? 'subscription' : 'one_time'`. `Subscriptions::Start`, `Plans::Holdings` and `PlanAudience` also test for Plan. This is the
  critical seam: the engine must ask the purchasable what to do, not test its class.
- **Fulfilment.** `SyncOrderEntitlementJob` and `Entitlement` assume a plan: `entitlements.plan_id` is required and the source is exactly one of
  a Pay subscription or an order. A top-up has no plan to point at.
- **Grants.** `plan_grants` belong to a plan only, and an add-on is forbidden from having any, so a quota top-up cannot say how much quota it gives.
- **Add-on flag.** `add_on` appears in about 19 files (checkout controller and view, hub, plan form, plan policy, tax preview, seeds). It is a
  flag on Plan standing in for a type.
- **Processor sync.** `SyncPlanJob`, `PlanSyncResult`, `ProcessorAdapter#sync_plan` and the `:plan_sync` capability are named and shaped for plans.
- **Seeds, forms, locales, DOM contracts, nav.** About 94 spec files reference the plan factory, and the seed type registry has `plan`,
  `plan grant` and add-on types.

## Where Stripe fits

Yes, Stripe uses products with prices, and the split should follow it:

- A **Product** is the thing sold: name, description, tax code, metadata. One product can have many prices.
- A **Price** belongs to a product. It is either one-time or recurring (`recurring.interval`, `interval_count`). Its amount, currency and recurrence
  are immutable: changing them means creating a new price and archiving the old one. It can carry a `lookup_key`, and `custom_unit_amount`
  (minimum, preset, maximum) for pay-what-you-want amounts such as donations.
- **Checkout Session** line items name a price, or give `price_data` and `product_data` inline with no pre-created objects. Mode is `payment`
  when every line is one-time, and `subscription` when any line recurs. One-time prices may sit beside a recurring one in subscription mode and
  are charged on the first invoice.
- **Subscriptions** hold items (a price and a quantity). A recurring add-on later maps to an extra subscription item.

What this means for CE:

- Today one `Plan` row holds one product id and one price id. That is a valid mirror of Stripe, but it cannot show two prices (monthly and annual)
  under one product, and it handles a price change by locking fields instead of archiving and replacing.
- One-off items map cleanly: a Product with one-time Prices, bought by quantity.
- Tickets and donations should use `price_data` inline. They need no sync to Stripe and no catalog rows in the processor.
- The adapter contract is not frozen: the Stripe extension (B0 to B7) is not built yet. This is the cheapest moment to generalize the contract,
  before a vendor adapter depends on `sync_plan`.

## Target shape

Keep `Plan` as the recurring subscription offer. Everything else sold becomes a different purchasable.

- **Plan** (existing table, narrowed). Subscription tiers only. Intervals `month` and `year`. Loses `one_time` and `add_on`. Keeps grace, renewal
  lead, plan change and hosted tier metadata.
- **Product** (new). A one-off item: top-up, one-time add-on, later other goods. Has catalog identity and processor mirror fields like a plan, plus
  grants, a list of plans it extends (optional), and prices.
- **Price** (new, child of Product). Amount, currency, one-time, active, processor price id. Immutable once linked: a change creates a new
  price and archives the old. The Price is the `Purchasable` a line item points at, taking its description and tax category from its Product.
  Plan keeps its embedded price for now and can move to this table later without affecting the order engine.
- **Shared parts** pulled out of Plan into concerns used by both Plan and Product: catalog listing and restriction, processor mirror and lock rules,
  translated presentation, agreement targeting. This shrinks Plan without changing its schema first.
- **Purchasable contract** gains fulfilment hooks, so the order engine never tests a class: what happens when an order line is paid
  (`fulfil`), refunded or cancelled (`revoke`), and what purpose the line implies. Plan answers "start a subscription". Product answers "grant
  these allowances for the quantity bought". Ticket types and donations answer in their own way later.
- **Grants** become attachable to either a plan or a product, with the amount multiplied by line quantity for products (three of a 10 GB
  top-up gives 30 GB).
- **Entitlement** gains a second possible source of "what gave this": a plan or a product, exactly one.

## Phases

Each phase is a separate PR, stacked on `feature/billing`, and each leaves the branch green.

1. **Decide and pin behaviour.** Owner answers the open questions below. Add characterization specs for what one-time plans and add-ons do today
   (checkout, settle, entitlement, refund, holdings) so later phases can prove nothing regressed.
2. **Extract shared concerns from Plan.** No schema change. Move catalog, processor mirror and presentation code into concerns. Plan shrinks and
   the seam for a second class appears.
3. **Fulfilment hooks.** Add the purchasable fulfil and revoke hooks, make Plan implement them, and replace the class checks in `Orders::Settle`,
   `Checkout::Methods`, `Subscriptions::Start`, `Plans::Holdings` and `PlanAudience`. Behaviour is unchanged, which the pinned specs prove.
   This is the most valuable phase, and tickets, donations and shares (D5 to D7) depend on it.
4. **Product and Price.** New tables, models, policies, steward screens, catalog and checkout step for products, grants for products, entitlement
   source change, seeds and locales in four languages. Top-ups work end to end here, through the offline methods.
5. **Move existing data.** Convert one-time plans and add-on plans to products, repoint line items, entitlements and `plan_add_ons`, then remove
   `one_time` and `add_on` from Plan along with their validations. The branch is not in a release yet and prod apps have billing off, so only test
   instances hold such rows. Use new migrations (not edits to unreleased ones) so test.communityengine.app migrates cleanly, and decide at merge time
   whether to squash.
6. **Processor contract.** Generalize `sync_plan` to sync a catalog item (product plus its prices, returning a result with a list of prices).
   Derive Checkout Session mode from the lines. Allow inline `price_data` for items with no processor mirror. Bump the contract version and keep a
   shim for adapters on the old version. Update `PriceInfo` and `processor-adapters.md`, and write the Stripe mapping table for the extension team.
7. **Cleanup.** Remove the dead plan add-on code, update nav route names, DOM contracts, screenshots, docs (`plan_catalog.md`, stories doc, MVP
   definition) and the assessment.

## Compatibility checks for the Stripe work

- Every item sold through Stripe resolves to a product id and a price id, or to inline `price_data`. No Stripe object is stored beyond ids.
- Price changes archive and replace, matching Stripe immutability, and orders keep their snapshot so history never changes.
- Currency stays per price. Multi-currency (`currency_options`) is out of scope for now.
- Webhooks: `checkout.session.completed` in payment mode settles an order; `invoice.paid` continues to drive subscription periods; `price.*` and
  `product.*` events feed the link and lock logic. These are adapter work, but the core contract in phase 6 must not block them.
- Tax stays computed by core and passed in, as the contract already requires.
- Promotions map to Stripe coupons and promotion codes only if the Stripe adapter wants them; core keeps its own redemption rules.

## Open questions for the owner

1. **Name.** Is `Product` acceptable? It matches Stripe, but community-commerce (Solidus, a different app) also has products. Alternatives: `Offer`,
   `Extra`, `Item`.
2. **Top-up lifetime.** Does a quota top-up last as long as the account, for a fixed term (a year), or until used? This decides whether an
   entitlement needs an end date and whether a refund claws it back.
3. **Quantity.** Can a buyer order several of a product in one line? Recommended yes, with grants multiplied.
4. **Add-ons that recur.** Is a monthly extra (seats, storage) ever sold? If so it stays a recurring Plan attached to a subscription, which is
   a later subscription-items change and not part of this work.
5. **Add-on targeting.** Keep "this product extends these plans" and "buyer must hold a plan" (the `plan_add_ons` rules), or let products sell to anyone?
6. **Tickets.** Confirm ticket types are their own purchasable with their own capacity, not products.
7. **Migration policy.** Confirm new migrations rather than editing unreleased ones, and whether to squash before merging to main.

## Risks

- Phase 3 touches the settle path, so a mistake there affects every paid order. The pinned specs and the existing concurrency and idempotency specs
  are the guard, and the phase must not change behaviour.
- The data move in phase 5 changes ids a line item points at. Run it in a transaction with counts checked before and after, and keep the old
  columns until the next release.
- Stripe fields may change in the extension gem. Keeping the core contract in plain value objects (as `PriceInfo` already is) limits the exposure.
