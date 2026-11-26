# Billing model assessment, November 2026

Decision (2026-11-26): a plan is a kind of product. It is bought through recurring prices, and everything that is bought is a price.

## Why the model changed

The first billing model had two catalog things that did nearly the same job. A `Plan` carried its own amount, currency, interval and processor price. A `Product` was sold through separate `Price` rows. Each had its own listing rules, tax category, processor mirror, grants and requirements, so every feature was written twice or written for one and missing for the other.

That showed up as real limits:

- A plan could only have one price. A monthly and an annual option, or a price in a second currency, meant a second plan.
- A product could not be sold on a subscription, because only plans renewed.
- Entitlements, grants, requirements and agreements each had a "plan" path and a "product" path.
- The processor contract needed a plan push and a catalog push.

## The model now

```mermaid
erDiagram
    PRODUCT ||--o{ PRICE : "is sold through"
    PRODUCT ||--o{ GRANT : "includes"
    PRODUCT ||--o{ REQUIREMENT : "needs"
    PRODUCT ||--o{ ENTITLEMENT : "gives"
    PRODUCT <|-- PLAN : "is a kind of"
    PLAN ||--o{ SUBSCRIPTION_TERM : "is subscribed to as"
    PRICE ||--o{ LINE_ITEM : "is bought as"
    PRICE ||--o{ SUBSCRIPTION_TERM : "sets the amount of"
    ORDER ||--|{ LINE_ITEM : "holds"
    SUBSCRIPTION_TERM ||--o{ ENTITLEMENT : "keeps alive"

    PRODUCT {
        uuid id
        string type "Product or Plan"
        string identifier
        string processor_product_id
        bool active
    }
    PRICE {
        uuid id
        string kind "one_time or recurring"
        int amount_cents
        string currency
        string interval "month or year"
        int interval_count
        string processor_price_id
        datetime archived_at
    }
    PLAN {
        int grace_days
        int renewal_lead_days
        string pricing_tier
    }
```

- **Product** is the one catalog entity: name, description, who may see and buy it, tax category, the processor's product id, what it grants, and its requirements and agreements.
- **Plan** is a Product subtype in the same table. It adds what only subscriptions need: grace days, renewal lead days, tiers, who it may be offered to, and the participant text.
- **Price** is the only thing that is bought. It has an amount, a currency, a kind (one time or recurring), and an interval for recurring ones. A price never changes once made. A change is a new price, and the old one is archived.
- **Order lines, subscription terms and entitlements** point at a price or a product. A term keeps the amount it started at, so renewals do not move when the catalog does.

## What this phase changed

- The `plans` table is gone. Plan rows moved into products with the same ids.
- Plan money moved onto recurring prices. A plan reads and writes its current price through virtual attributes, so forms and the processor field locks keep working.
- Orders buy a price. Naming a plan or a product in an order line buys the price it is sold at today.
- Subscription terms, renewals, plan change and period maths use the price.
- Entitlements and grants are keyed by product.
- One sync job (`SyncProductJob`) pushes a product and its prices. `SyncPlanJob` and the converter service are removed.

## What the later phases do

2. One grant model: `PlanGrant` became `Grant` (table `better_together_billing_grants`), and an entitlement recomputes from every live source, so a grant ends only when none remain.
3. One processor contract: a single catalog sync, checkout by mode and lines, no version numbers, and the plan push removed.
4. Names and screens: one `GrantsController` at `products/:product_id/grants` serves products and plans (a plan is a product), the nested `plan_grants` route and controller are gone, locale keys moved from `billing.plan_grants` to `billing.grants`, and a plan page lists all of its prices through the same partial a product page uses. The demo seed packet already loads through the unified models.

## Risks and checks

- Nothing billing-related is in production, so the migration is destructive and there is no data to carry. The test app is reset and reseeded after merge.
- Mobility stores translations against the base class, so a plan's extra translated fields use their own association names. Without that, a second `translates` call on the subclass hid the product's own translations.
- A price on a linked plan is read from the processor and never pushed, so creating a linked plan enqueues nothing.
