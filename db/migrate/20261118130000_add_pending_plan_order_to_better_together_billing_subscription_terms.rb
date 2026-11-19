# frozen_string_literal: true

# The invoice for the difference when a subscriber moves to a dearer plan straight away; the plan moves when it is paid. Guarded.
class AddPendingPlanOrderToBetterTogetherBillingSubscriptionTerms < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_subscription_terms

  def up
    return unless table_exists?(TABLE) && !column_exists?(TABLE, :pending_plan_order_id)

    add_reference TABLE, :pending_plan_order, type: :uuid, null: true, index: { name: 'idx_bt_billing_terms_pending_order' },
                                              foreign_key: { to_table: :better_together_billing_orders, on_delete: :nullify }
  end

  def down
    return unless table_exists?(TABLE) && column_exists?(TABLE, :pending_plan_order_id)

    remove_reference TABLE, :pending_plan_order, foreign_key: { to_table: :better_together_billing_orders },
                                                 index: { name: 'idx_bt_billing_terms_pending_order' }
  end
end
