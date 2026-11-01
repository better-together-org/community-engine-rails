# frozen_string_literal: true

class CreateBetterTogetherQuotaBalances < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_quota_balances)

    create_bt_table :quota_balances do |t|
      # target_table pinned to the singular table - see the identical comment in
      # 20261028220100_create_better_together_quota_usages.rb for why.
      t.bt_references :quota, target_table: :better_together_quota, null: false,
                              index: { name: 'index_bt_quota_balances_on_quota' }
      t.string :period_key, null: false
      t.bigint :consumed, null: false, default: 0
      t.bigint :reserved, null: false, default: 0
      t.datetime :recalculated_at
    end

    add_index :better_together_quota_balances, %i[quota_id period_key],
              unique: true, name: 'index_bt_quota_balances_on_quota_and_period'
  end
end
