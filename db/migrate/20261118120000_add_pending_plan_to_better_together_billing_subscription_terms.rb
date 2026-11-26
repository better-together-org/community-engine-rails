# frozen_string_literal: true

# A subscriber's chosen new plan, applied when the next period starts (see Subscriptions::ChangePlan). Guarded.
class AddPendingPlanToBetterTogetherBillingSubscriptionTerms < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_subscription_terms

  def up
    return unless table_exists?(TABLE)

    unless column_exists?(TABLE, :pending_plan_id)
      add_reference TABLE, :pending_plan, type: :uuid, null: true, index: { name: 'idx_bt_billing_terms_pending_plan' },
                                          foreign_key: { to_table: :better_together_billing_plans, on_delete: :nullify }
    end
    add_column TABLE, :pending_plan_requested_at, :datetime unless column_exists?(TABLE, :pending_plan_requested_at)
  end

  def down
    return unless table_exists?(TABLE)

    if column_exists?(
      TABLE, :pending_plan_id
    )
      remove_reference TABLE, :pending_plan, foreign_key: { to_table: :better_together_billing_plans },
                                             index: { name: 'idx_bt_billing_terms_pending_plan' }
    end
    remove_column TABLE, :pending_plan_requested_at if column_exists?(TABLE, :pending_plan_requested_at)
  end
end
