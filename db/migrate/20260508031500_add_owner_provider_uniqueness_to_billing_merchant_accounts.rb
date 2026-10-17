# frozen_string_literal: true

class AddOwnerProviderUniquenessToBillingMerchantAccounts < ActiveRecord::Migration[7.2]
  INDEX_NAME = 'idx_bt_billing_merchant_accounts_owner_provider'

  def change
    return unless table_exists?(:better_together_billing_merchant_accounts)
    return if index_exists?(:better_together_billing_merchant_accounts, %i[owner_type owner_id provider], name: INDEX_NAME)

    add_index :better_together_billing_merchant_accounts, %i[owner_type owner_id provider],
              unique: true,
              name: INDEX_NAME
  end
end
