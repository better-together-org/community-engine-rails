# frozen_string_literal: true

# better_together_quota_balances was created without a platform_id column, which
# QuotaBalance < PlatformRecord requires via PlatformScoped. Fixing with a new
# migration rather than editing the original create migration, since it already ran.
class AddPlatformToBetterTogetherQuotaBalances < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_quota_balances, :platform_id)

    add_reference :better_together_quota_balances, :platform,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
