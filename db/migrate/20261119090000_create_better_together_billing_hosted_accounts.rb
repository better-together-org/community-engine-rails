# frozen_string_literal: true

# One row per hosted platform that has dealt with the host about billing: whether the host has suspended its billing. What the platform
# has accepted lives in the shared agreement acceptance records, not here. Guarded so a re-run is a no-op.
class CreateBetterTogetherBillingHostedAccounts < ActiveRecord::Migration[7.2]
  def up
    return if table_exists?(:better_together_billing_hosted_accounts)

    create_bt_table :billing_hosted_accounts do |t|
      t.uuid :platform_id, null: false
      t.string :status, null: false, default: 'active'
      t.datetime :suspended_at
      t.uuid :suspended_by_id
      t.text :suspension_reason
    end

    add_index :better_together_billing_hosted_accounts, :platform_id, unique: true, name: 'idx_bt_billing_hosted_accounts_platform'
    add_foreign_key :better_together_billing_hosted_accounts, :better_together_platforms, column: :platform_id
  end

  def down
    drop_table :better_together_billing_hosted_accounts if table_exists?(:better_together_billing_hosted_accounts)
  end
end
