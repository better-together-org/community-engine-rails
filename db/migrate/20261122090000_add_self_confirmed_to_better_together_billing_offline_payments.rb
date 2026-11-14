# frozen_string_literal: true

# Whether a steward confirmed a payment for their own purchase (only allowed when no other steward could). Guarded.
class AddSelfConfirmedToBetterTogetherBillingOfflinePayments < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_offline_payments

  def up
    return unless table_exists?(TABLE) && !column_exists?(TABLE, :self_confirmed)

    add_column TABLE, :self_confirmed, :boolean, null: false, default: false
  end

  def down
    return unless table_exists?(TABLE) && column_exists?(TABLE, :self_confirmed)

    remove_column TABLE, :self_confirmed
  end
end
