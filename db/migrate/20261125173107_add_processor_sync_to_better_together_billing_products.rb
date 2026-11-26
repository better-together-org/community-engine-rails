# frozen_string_literal: true

# PS-7: a product held by an online processor keeps the state of its last push, as a plan does.
class AddProcessorSyncToBetterTogetherBillingProducts < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_products

  def change
    return unless table_exists?(TABLE)

    add_column TABLE, :sync_status, :string, null: false, default: 'synced' unless column_exists?(TABLE, :sync_status)
    add_column TABLE, :sync_error, :string unless column_exists?(TABLE, :sync_error)
    add_column TABLE, :sync_attempted_at, :datetime unless column_exists?(TABLE, :sync_attempted_at)
    add_column TABLE, :synced_to_processor_at, :datetime unless column_exists?(TABLE, :synced_to_processor_at)
  end
end
