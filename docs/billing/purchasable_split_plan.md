# Splitting one-off purchases out of Plan: remediation plan

Status: proposed 2026-11-24 against `feature/billing` at `920635b8a`. Revised the same day with the owner's answers (see "Decisions made").
Items still marked open need an answer before the phase that depends on them.

## Decisions made

- The new purchasable is named `Product`.
- A top-up lasts until used by default, and each top-up product can be configured instead to last for a fixed term.
- A buyer can order several units of a product on one line. Grants multiply by quantity.
- Ticket types are a subtype of `Product`, like other one-off purchasables, using single table inheritance. The subclass carries the behaviour, and a
  detail record holds the subtype's own attributes. The ticket type is the product subclass. A ticket is an issued instance of a ticket type: a join
  record between the ticket type and an optional holder. Nothing ticket-specific lives on the product table.
- Add-ons are not a type. They are one case of a general **dependent purchases** mechanism: any purchasable can require that the buyer holds, or is
  ordering, some other purchasable. It applies to plans, products, ticket types and later purchasables alike. Both "must already hold" and "or is buying
  it now" are available and configurable per rule. Examples: a gala ticket only for people ordering or already holding a conference registration
  ticket; a plan add-on only for people holding or ordering a particular plan.

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
- **Processor sync.** `SyncProductJob`, `PlanSyncResult`, `ProcessorAdapter#sync_plan` and the plan sync capability were named and shaped for plans (now one catalog sync: see the model assessment).
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
- **Product subtypes (STI).** `Product` is the standard product (a top-up or one-time add-on), fulfilled through its grants. A non-standard kind is a
  subclass that overrides the hooks the purchasable contract asks of a product. The first is `Billing::Products::TicketType`, which is what a buyer
  chooses and pays for. Attributes that only one subtype has live in a `has_one` detail record, so the shared table has no empty columns. For ticket
  types they are expected to include the event or occurrence, capacity, per-person limit and sales window.
- **Tickets.** A ticket is an issued instance of a ticket type: a record joining the ticket type to an optional holder (a person), and to the order line
  that paid for it. It is not a purchasable and carries no authored text. The ticket type's hooks work through tickets: `reserve!` and `release!` hold
  capacity against issued and pending tickets, `fulfil` issues one ticket per unit of quantity (unassigned unless the buyer is the only holder, so a
  buyer of five can assign them later), `revoke` voids the tickets of a refunded line, and "does this person hold you" means they hold a valid
  ticket. Holder assignment, transfer and check-in are designed with D7, not in this stack.
- **What this stack builds.** The base `Product`, the subtype seam, and a test subclass with a test issued-instance model in specs, so the hooks are
  proven before D7. The `type` column is only ever set from an allow-list of subclasses (never from a parameter), and line items and translations
  store the base class name, so one allow-list entry for `Billing::Product` covers every subclass.
- **Purchasable contract** gains fulfilment hooks, so the order engine never tests a class: what happens when an order line is paid
  (`fulfil`), refunded or cancelled (`revoke`), and what purpose the line implies. Plan answers "start a subscription". Product answers "grant
  these allowances for the quantity bought". Ticket types and donations answer in their own way later.
- **Grants** become attachable to either a plan or a product, with the amount multiplied by line quantity for products (three of a 10 GB
  top-up gives 30 GB).
- **Entitlement** gains a second possible source of "what gave this": a plan or a product, exactly one.
- **Top-up lifetime** is a per-product setting. `until_used` (the default) means the grant has no end date and is spent as the buyer uses it. `fixed_term`
  means it ends after a configured length (for example 12 months from payment). A refund or cancellation revokes the grant in both cases. How
  "until used" behaves depends on the quota type: a consumable one (tokens, sends) is drawn down, while a capacity one (storage bytes) is not consumed, so
  until used simply means it stays while the purchase stands. Phase 1 confirms how `Entitlements::QuotaAllowances` and the quota framework combine an
  allowance with a base limit, so a top-up is added to the limit and the draw-down is recorded in one place.
- **What the quota code does today (PS-1 finding).** A quota grant is not a balance. `Quotas.effective_limit` is the type's default plus the sum of
  every live applied grant (`Entitlements::QuotaAllowances`), and `sync_limit!` writes that onto the quota. Usage is counted separately against the
  limit for a period key: `cumulative` (media storage), `monthly` (AI translation tokens) or `daily`. Nothing is drawn down from the grant, and an
  entitlement with no end date keeps its grant for good. Two consequences for top-ups:
  1. A storage top-up (cumulative, reversible) works as designed: it raises the limit for as long as the purchase stands.
  2. A token top-up would raise the monthly limit every month with no end, which is a subscription-sized benefit from a one-off payment.
     **Decided (2026-11-24): token grants stay time-limited.** A top-up for a monthly or daily quota type must be a fixed term, so no consumable
     balance is built. The product form offers `until_used` only for cumulative types (storage) and requires a fixed term for the others.
- **Dependent purchases** replace the add-on flag and the `plan_add_ons` table with one generic rule table (below).

## Dependent purchases

A **purchase requirement** says: this purchasable may only be bought by someone who meets one of its prerequisites. It is a record with:

- the dependent purchasable (a plan, product, ticket type or any other registered purchasable, resolved through the same allow-list the line items use);
- a prerequisite, either one specific purchasable or a kind (for example "any plan", which is what an add-on with no links means today);
- how it is met: `holding` (the buyer already has it), `in_order` (the same order contains it), or `either` (the default);
- optional scope, so a gala ticket's prerequisite is a conference ticket for the same event and not any ticket;
- what happens to the dependent when the prerequisite ends: keep it, or revoke it with the prerequisite.

A purchasable with several rules is available when any one rule is met by default, and a rule can be marked required so it must be met as well. Cycles
are refused when a rule is saved.

How it is evaluated, always on the server:

- The catalog and the checkout offer a dependent only to people who qualify, and show an unqualified buyer a short reason instead of hiding it when the
  seller chooses to list it.
- `Orders::Place` checks every line against the buyer's holdings plus the other lines in the same order. The checkout add-on step becomes "things that go
  with what you are buying" and is built from the rules, so it works for any prerequisite and not only plans.
- Each purchasable answers one question for the engine: "does this person hold you right now?" A plan says yes for a live subscription or entitlement, a
  product for a live grant or a paid order that stands, a ticket type for a valid issued ticket. That one hook replaces `Plans::Holdings`.
- Refund or cancellation of a prerequisite follows the rule's setting. Unpaid dependent lines in the same order are cancelled with it.

Today's add-ons convert directly: an add-on plan becomes a product, its `plan_add_ons` links become rules ("holding or ordering this plan"), and an
add-on with no links becomes a rule on the kind "any plan".

## Phases

Each phase is a separate PR, stacked on `feature/billing`, and each leaves the branch green.

1. **Pin behaviour and read the quota code.** Add characterization specs for what one-time plans and add-ons do today (checkout, settle, entitlement,
   refund, holdings, add-on eligibility) so later phases can prove nothing regressed. Confirm how quota allowances combine with base limits, which
   fixes how a top-up is added and drawn down.
2. **Extract shared concerns from Plan.** No schema change. Move catalog, processor mirror and presentation code into concerns. Plan shrinks and
   the seam for a second class appears.
3. **Fulfilment and holding hooks.** Add the purchasable `fulfil`, `revoke` and "does this person hold you" hooks, make Plan implement them, and replace
   the class checks in `Orders::Settle`, `Checkout::Methods`, `Subscriptions::Start`, `Plans::Holdings` and `PlanAudience`. Behaviour is unchanged,
   which the pinned specs prove. This is the most valuable phase, and tickets, donations and shares (D5 to D7) depend on it.
4. **Dependent purchases.** Add the purchase requirement table and its evaluation in the catalog, checkout and `Orders::Place`, with plans as the
   first dependents and prerequisites. Existing add-ons keep working through a compatibility reader until phase 6. Steward screens to define rules,
   in four languages, with DOM contracts and screenshots.
5. **Product and Price.** New tables, models, policies, steward screens, catalog and checkout for products, grants for products with quantity, the
   per-product lifetime setting, entitlement source change, seeds and locales. Top-ups work end to end here, through the offline methods, including
   fixed-term expiry and revocation on refund.
6. **Move existing data.** Convert one-time plans and add-on plans to products, links to purchase requirements, and repoint line items and
   entitlements. Then remove `one_time` and `add_on` from Plan, the `plan_add_ons` table and their validations. The branch is not in a release yet
   and prod apps have billing off, so only test instances hold such rows. Use new migrations (not edits to unreleased ones) so
   test.communityengine.app migrates cleanly, and decide at merge time whether to squash.
   **Built (PS-6):** `Products::ConvertPlans` (since removed, see the [model assessment](assessments/2026-11-billing-model-assessment.md)) plus two migrations (convert, then drop `plan_add_ons` and `plans.add_on`); `one_time` is gone
   from `BILLING_INTERVALS`. See [products and prices](products_and_prices.md).
7. **Processor contract.** Generalize `sync_plan` to sync a catalog item (product plus its prices, returning a result with a list of prices).
   Derive Checkout Session mode from the lines. Allow inline `price_data` for items with no processor mirror. Bump the contract version and keep a
   shim for adapters on the old version. Update `PriceInfo` and `processor-adapters.md`, and write the Stripe mapping table for the extension team.
   **Built (PS-7):** contract version 2 (`sync_catalog_item`, `mode:` and `lines:`), `CatalogSync`, `SyncProductJob`, `ProductMirror`, `Checkout::Lines`;
   version 1 adapters keep working. See [processor adapters](processor-adapters.md#contract-versions). A steward screen for a product's processor is left for later.
8. **Cleanup.** Remove dead add-on code, update nav route names, DOM contracts, screenshots, docs (`plan_catalog.md`, stories doc, MVP definition)
   and the assessment.
   **Built (PS-8):** the unused add-on locale keys are gone in en, es, fr and uk; MVP definition, stories doc, plan catalog and the assessment refresh say
   products and extras. The code was already clear of `add_on` on Plan. Checkout and hub keep the `add_on` ids and `add_on_ids[]` for extras, so DOM contracts and screenshots are unchanged.

## Translatable attributes (decided before any model is written)

Rule from the localization standard: text a person or steward writes and a buyer reads is a Mobility translated attribute with an explicit type, and
nothing else is. `string` is a short value, `text` is long copy. Static labels and messages are I18n keys in en, es, fr and uk.

### Existing Plan attributes

No type changes. Plan keeps what it has today, so no data moves between the string and text translation tables:

| Attribute | Type | Stays on Plan or shared |
|---|---|---|
| `name` | string | shared with Product (concern) |
| `description` | text | shared with Product (concern) |
| `beneficiary_label` | string | Plan only (who a tier is for) |
| `solidarity_description` | string | Plan only (solidarity pricing tiers) |
| `participant_summary` | text | Plan only. Product gets its own `summary`, below |
| `participant_benefits` | text | Plan only. A product's contents come from its grants, written by `billing_plan_grant_summary`, so there is nothing to type |

When phase 2 moves `name` and `description` into a shared concern, the `translates` calls keep the same explicit types. The check is that
`bin/export_localized_attributes --check` shows no change for Plan.

### New models

| Model | Attribute | Type | Why |
|---|---|---|---|
| Product | `name` | string | A short title buyers read in the catalog, checkout, invoice and receipt. Required. Same as `Plan.name`. |
| Product | `description` | text | Long copy on the catalog and detail page. Same as `Plan.description`. |
| Product | `summary` | text | The one or two lines shown beside the name in a checkout list and catalog card (what add-ons show today through `participant_summary`). Text, matching `Plan.participant_summary`, so a steward is never cut short. |
| Price | `label` | string | Optional short name for a price when a product has several (for example "Early bird", "Member"). Shown beside the amount. Stripe's price nickname is internal, so this is separate from anything sent to the processor. |
| Purchase requirement | `unmet_message` | string | Optional one line shown to a buyer who does not qualify ("Open to people registered for the conference"). Capped at 200 characters in validation so it stays one line. When blank, the screen uses a default I18n sentence built from the prerequisite's name. |
| Line item | `description` | string | Already translated. A product line snapshots the product name (and price label if set) in every language through `LocalizedSnapshot`. No change to the model. |

Not translatable, on purpose: `identifier`, the Stripe `lookup_key`, processor product and price ids, amounts, currencies, lifetime setting and term
length, quantity limits, the requirement mode and scope, and the grant parameters (they are structured data, and the readable sentence is built from
I18n). Order and entitlement records hold no authored text.

Ticket types are a Product subclass, so they take `name`, `description` and `summary` from the product and need no separate copy. Any text the ticket
detail record adds (for example attendee instructions such as "what to bring") is decided with D7, as text if it is more than a line, and is outside this
stack.

### Static I18n keys needed in all four locales

Product screens and forms, lifetime options (until used, fixed term, term units), requirement modes (holding, in order, either), the default unmet
sentence, the "things that go with what you are buying" checkout heading and hint, locked-listing reasons, validation errors for the new models, and
the nav and route-name labels. es, fr and uk text is written by us and still needs a native review.

### Gates when the models land

Phases 4 and 5 add the models, so each of those PRs regenerates and commits the localized attribute diagram with `bin/export_localized_attributes`,
passes `bin/dc-run bin/i18n`, seeds a default `name` for any seeded product (required translated fields are seeded, not left to fall back), and
permits the translated attributes through `permitted_attributes`. This base PR is documentation only, so it changes no diagram.

## Compatibility checks for the Stripe work

- Every item sold through Stripe resolves to a product id and a price id, or to inline `price_data`. No Stripe object is stored beyond ids.
- Price changes archive and replace, matching Stripe immutability, and orders keep their snapshot so history never changes.
- Currency stays per price. Multi-currency (`currency_options`) is out of scope for now.
- Webhooks: `checkout.session.completed` in payment mode settles an order; `invoice.paid` continues to drive subscription periods; `price.*` and
  `product.*` events feed the link and lock logic. These are adapter work, but the core contract in phase 6 must not block them.
- Tax stays computed by core and passed in, as the contract already requires.
- Promotions map to Stripe coupons and promotion codes only if the Stripe adapter wants them; core keeps its own redemption rules.

## Open questions for the owner

Answered: name (`Product`), top-up lifetime (until used by default, fixed term per product), quantity (yes), dependent purchases (generic, "holding" and
"in order" both available).

1. **Recurring extras.** Is a monthly extra (seats, storage) ever sold? If so it stays a recurring Plan that depends on another plan through a purchase
   requirement, and a later change maps it to a Stripe subscription item. Not part of this work.
2. **Subtype shape.** Ticket types are decided: an STI subclass of Product with a detail record. Still to confirm is whether top-ups become a
   subclass too, or stay the standard product with lifetime on the product because any product with grants can have a lifetime. The plan keeps it on the
   product.
3. **Migration policy.** Confirm new migrations rather than editing unreleased ones, and whether to squash before merging to main.
4. **Revoking a dependent.** The default when a prerequisite is refunded or ends: keep the dependent, or revoke it? The plan makes it a per-rule
   setting. A default is needed (proposal: keep, except for tickets, which revoke).
5. **Locked listings.** When a buyer does not qualify, should a dependent be hidden or shown with a reason? The plan makes it a per-purchasable
   setting. A default is needed (proposal: shown with a reason).

## Risks

- Phase 3 touches the settle path, so a mistake there affects every paid order. The pinned specs and the existing concurrency and idempotency specs
  are the guard, and the phase must not change behaviour.
- The data move in phase 5 changes ids a line item points at. Run it in a transaction with counts checked before and after, and keep the old
  columns until the next release.
- Stripe fields may change in the extension gem. Keeping the core contract in plain value objects (as `PriceInfo` already is) limits the exposure.
