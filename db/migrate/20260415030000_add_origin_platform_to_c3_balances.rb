# frozen_string_literal: true

# Adds origin_platform_id to C3::Balance so federated balances are tracked
# separately from locally-earned balances.
#
# A nil origin_platform_id means the balance was earned on this platform.
# A non-nil value means these tokens were received via C3 federation from
# the identified origin platform.
#
# This column is required for GET /api/v1/c3/network_balance to work.
class AddOriginPlatformToC3Balances < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_c3_balances, :origin_platform_id)

    add_column :better_together_c3_balances, :origin_platform_id, :uuid, null: true
    add_foreign_key :better_together_c3_balances, :better_together_platforms,
                    column: :origin_platform_id, on_delete: :nullify
    add_index :better_together_c3_balances, :origin_platform_id,
              name: 'idx_bt_c3_balances_origin_platform',
              where: 'origin_platform_id IS NOT NULL'
  end
end
