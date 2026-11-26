# Purchase requirements

A purchase requirement says a purchasable may only be bought by someone who meets a prerequisite. What used to be an add-on plan is now a product with rules: the same thing as any other dependent purchase.

## The rule

| Field | Meaning |
|---|---|
| dependent | The purchasable being restricted: a product (a rule on a product covers every price of it) or any registered purchasable. |
| prerequisite | One specific purchasable, or a `prerequisite_kind` (`plan` is any plan). Exactly one of the two. |
| `met_by` | `holding` (the buyer already has it), `in_order` (the same order contains it), or `either` (default). |
| `required` | With several rules, a dependent needs any one met, plus every required rule. |
| `on_prerequisite_end` | `keep` (default) or `revoke` the dependent when the prerequisite is refunded or cancelled. Tickets will use `revoke`. |

Rules refuse a dependent or prerequisite that is not a registered purchasable, a rule that needs itself, a loop of rules, a duplicate, and a rule with both or neither target. Both ends are resolved through the Purchasable registry.

## Extras

A product with at least one rule is an **extra**: its prices ride along on a plan's order and can be bought later by someone who holds a plan it needs. A steward sets the rules on the product form (`billing-product-requirements`): tick "needs any plan", or tick the plans it goes with. Nothing ticked means it sells on its own. PS-6 converted the old add-on plans and their `PlanAddOn` links into products with these rules (`Products::the plan conversion (removed in the plan-as-product change)`, run by a migration).

## Where it is enforced

- `Orders::Place` checks every line against what the buyer holds plus the other lines in the same order, on the server, and refuses with the reason. A renewal and a steward's walk-up sale are exempt.
- The checkout offers an extra only when the plan being bought, or one the buyer holds, meets its rules. `PricePolicy#buy_alone?` uses the same evaluation.
- The billing hub lists extras that are for sale but locked, each with the reason (`Needs a plan`), instead of hiding them.

`PurchaseRequirements::Evaluate` returns the unmet rules; `reason` words them in the reader's language. Holding is asked of the prerequisite itself (`Purchasable#held_by?`), so a plan, a product or a ticket type each answer in their own terms.

## When a prerequisite ends

`Orders::Settle` queues `RevokeDependentsJob` when an order is refunded or cancelled and some rule with `on_prerequisite_end: revoke` names one of its purchasables. `RevokeDependents` finds the buyer's other paid lines for the dependents, unless the buyer still holds the prerequisite another way, and calls `Purchasable#revoke_line` on each. The default does nothing; a purchasable that gives something overrides it and must be safe to repeat.

## Data

Table `better_together_billing_purchase_requirements`, see [the schema ERD](../diagrams/source/billing_schema_erd.mmd). A check constraint keeps exactly one of prerequisite and kind, and unique indexes stop duplicate rules.
