# frozen_string_literal: true

# PS-6: add-ons and one-time plans are products now, and what an add-on extended is a purchase requirement, so the plan add-on
# links and the plan `add_on` flag are gone. Refuses to run while any plan is still an add-on or one-time (the move before
# this one leaves none), so nothing is dropped that was not first converted. Guarded so a re-run is a no-op.
class DropPlanAddOnsAndAddOnFromPlans < ActiveRecord::Migration[7.2]
  PLANS = :better_together_billing_plans
  LINKS = :better_together_billing_plan_add_ons

  def up
    ensure_nothing_left
    drop_table LINKS if table_exists?(LINKS)
    remove_column PLANS, :add_on if column_exists?(PLANS, :add_on)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def ensure_nothing_left
    return unless column_exists?(PLANS, :add_on)

    left = select_value("SELECT COUNT(*) FROM #{PLANS} WHERE add_on OR billing_interval = 'one_time'").to_i
    raise "#{left} plan(s) are still add-ons or one-time; run the conversion to products first" if left.positive?
  end
end
