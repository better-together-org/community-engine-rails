# frozen_string_literal: true

class CreateBetterTogetherQuotaBalances < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_quota_balances)

    create_bt_table :quota_balances do |t|
      t.bt_references :quota, null: false, index: { name: 'index_bt_quota_balances_on_quota' }
      t.string :period_key, null: false
      t.bigint :consumed, null: false, default: 0
      t.bigint :reserved, null: false, default: 0
      t.datetime :recalculated_at
    end

    add_index :better_together_quota_balances, %i[quota_id period_key],
              unique: true, name: 'index_bt_quota_balances_on_quota_and_period'
  end
end
