# frozen_string_literal: true

# better_together_quota_reservations was created without a platform_id column, which
# QuotaReservation < PlatformRecord requires via PlatformScoped, so every reserve!
# failed validation. Same follow-up fix as AddPlatformToBetterTogetherQuotaBalances.
class AddPlatformToBetterTogetherQuotaReservations < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_quota_reservations, :platform_id)

    add_reference :better_together_quota_reservations, :platform,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
