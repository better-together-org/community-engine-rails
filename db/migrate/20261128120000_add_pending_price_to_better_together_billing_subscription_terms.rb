# frozen_string_literal: true

# The price a subscriber chose to move to (a plan's other interval, or another plan's price). Guarded.
class AddPendingPriceToBetterTogetherBillingSubscriptionTerms < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_subscription_terms

  def up
    return unless table_exists?(TABLE) && !column_exists?(TABLE, :pending_price_id)

    add_reference TABLE, :pending_price, type: :uuid, null: true, index: { name: 'idx_bt_billing_terms_pending_price' },
                                         foreign_key: { to_table: :better_together_billing_prices, on_delete: :nullify }
  end

  def down
    return unless table_exists?(TABLE) && column_exists?(TABLE, :pending_price_id)

    remove_reference TABLE, :pending_price, foreign_key: { to_table: :better_together_billing_prices },
                                            index: { name: 'idx_bt_billing_terms_pending_price' }
  end
end
