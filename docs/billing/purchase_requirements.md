# Purchase requirements

A purchase requirement says a purchasable may only be bought by someone who meets a prerequisite. It replaces the add-on special case: an add-on that extends plans is now the same thing as any other dependent purchase.

## The rule

| Field | Meaning |
|---|---|
| dependent | The purchasable being restricted: any registered purchasable (a plan today; products and ticket types later). |
| prerequisite | One specific purchasable, or a `prerequisite_kind` (`plan` is any primary plan). Exactly one of the two. |
| `met_by` | `holding` (the buyer already has it), `in_order` (the same order contains it), or `either` (default). |
| `required` | With several rules, a dependent needs any one met, plus every required rule. |
| `on_prerequisite_end` | `keep` (default) or `revoke` the dependent when the prerequisite is refunded or cancelled. Tickets will use `revoke`. |

Rules refuse a dependent or prerequisite that is not a registered purchasable, a rule that needs itself, a loop of rules, a duplicate, and a rule with both or neither target. Both ends are resolved through the Purchasable registry.

## Add-ons keep working

A dependent with no stored rules and `add_on: true` gets the rules its links imply, built in memory: one rule per plan it extends, or the kind `plan` when it names none. Nothing is written, so existing add-ons behave as before until their data is moved to stored rules.

## Where it is enforced

- `Orders::Place` checks every line against what the buyer holds plus the other lines in the same order, on the server, and refuses with the reason. A renewal and a steward's walk-up sale are exempt.
- The checkout offers an add-on only when the plan being bought, or one the buyer holds, meets its rules. `PlanPolicy#buy_alone?` uses the same evaluation.
- The billing hub lists add-ons that are for sale but locked, each with the reason (`Needs a plan`), instead of hiding them.

`PurchaseRequirements::Evaluate` returns the unmet rules; `reason` words them in the reader's language. Holding is asked of the prerequisite itself (`Purchasable#held_by?`), so a plan, a product or a ticket type each answer in their own terms.

## When a prerequisite ends

`Orders::Settle` queues `RevokeDependentsJob` when an order is refunded or cancelled and some rule with `on_prerequisite_end: revoke` names one of its purchasables. `RevokeDependents` finds the buyer's other paid lines for the dependents, unless the buyer still holds the prerequisite another way, and calls `Purchasable#revoke_line` on each. The default does nothing; a purchasable that gives something overrides it and must be safe to repeat.

## Data

Table `better_together_billing_purchase_requirements`, see [the schema ERD](../diagrams/source/billing_schema_erd.mmd). A check constraint keeps exactly one of prerequisite and kind, and unique indexes stop duplicate rules.
