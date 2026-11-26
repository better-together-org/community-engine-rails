# frozen_string_literal: true

# PS-6: add-ons and one-time plans are products now, and what an add-on extended is a purchase requirement, so the plan add-on
# links and the plan `add_on` flag are gone. A plan still marked an add-on or one-time is not refused: MergePlansIntoProducts
# (later) turns every such row into a product with a one-time price, keeping its id. Guarded so a re-run is a no-op.
class DropPlanAddOnsAndAddOnFromPlans < ActiveRecord::Migration[7.2]
  PLANS = :better_together_billing_plans
  LINKS = :better_together_billing_plan_add_ons

  def up
    drop_table LINKS if table_exists?(LINKS)
    remove_column PLANS, :add_on if column_exists?(PLANS, :add_on)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
