# frozen_string_literal: true

# What a walk-up sale records about the buyer beyond the person: the email billing notices go to (it may differ
# from the one on the person, and a new buyer has only this one) and the billing address given at the sale.
# Both hold personal data, so both are ENCRYPTED text columns (no default, no limit; the billing address is JSON).
# Guarded so a re-run, or an interrupted earlier run, is a no-op for what exists.
class AddWalkUpBuyerDetailsToBetterTogetherBillingOrders < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_orders

  def up
    add_column TABLE, :buyer_email, :text unless column_exists?(TABLE, :buyer_email)
    add_column TABLE, :billing_address, :text unless column_exists?(TABLE, :billing_address)
  end

  def down
    remove_column TABLE, :billing_address if column_exists?(TABLE, :billing_address)
    remove_column TABLE, :buyer_email if column_exists?(TABLE, :buyer_email)
  end
end
