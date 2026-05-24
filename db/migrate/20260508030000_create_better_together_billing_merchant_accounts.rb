# frozen_string_literal: true

class CreateBetterTogetherBillingMerchantAccounts < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_billing_merchant_accounts)

    create_bt_table :billing_merchant_accounts do |t|
      t.references :owner,
                   type: :uuid,
                   polymorphic: true,
                   null: false,
                   index: { name: 'idx_bt_billing_merchant_accounts_owner' }
      t.string :provider, null: false
      t.string :external_account_id
      t.string :status, null: false, default: 'pending'
      t.boolean :charges_enabled, null: false, default: false
      t.boolean :payouts_enabled, null: false, default: false
      t.jsonb :capabilities, null: false, default: {}
      t.string :country
      t.string :currency
      t.jsonb :metadata, null: false, default: {}
      t.datetime :last_synced_at
    end

    add_index :better_together_billing_merchant_accounts, %i[provider external_account_id],
              unique: true,
              where: 'external_account_id IS NOT NULL',
              name: 'idx_bt_billing_merchant_accounts_external'
    add_index :better_together_billing_merchant_accounts, :provider,
              name: 'idx_bt_billing_merchant_accounts_provider'
    add_index :better_together_billing_merchant_accounts, :status,
              name: 'idx_bt_billing_merchant_accounts_status'
  end
end
