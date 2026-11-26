# frozen_string_literal: true

# PS-6: what was sold once as a plan (a one-time plan, or an add-on) becomes a product with one price. Grants, entitlements,
# agreement requirements and the lines of past orders follow it, and what an add-on extended becomes purchase requirements
# on the product. Counts are checked inside one transaction, so a mismatch leaves the database as it was. Nothing to do on
# a database with no such plans, or one that was never given the old columns. See docs/billing/purchasable_split_plan.md.
class ConvertOneTimePlansToProducts < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:better_together_billing_products) && table_exists?(:better_together_billing_purchase_requirements)
    return unless column_exists?(:better_together_billing_plans, :add_on)

    BetterTogether::Billing::Products::ConvertPlans.call
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
