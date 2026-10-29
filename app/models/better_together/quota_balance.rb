# frozen_string_literal: true

module BetterTogether
  # Materialized consumed/reserved totals for one Quota and one period, recalculated
  # under a row lock whenever BetterTogether::Quotas writes a usage or reservation,
  # a cache of quota_usages, never a source of truth on its own.
  class QuotaBalance < PlatformRecord
    belongs_to :quota

    validates :period_key, presence: true
    validates :quota_id, uniqueness: { scope: :period_key }
    validates :consumed, :reserved, numericality: { only_integer: true }

    # Recomputes consumed/reserved for one quota+period from the ledger and persists
    # it, under a row lock on the owning Quota so concurrent settle!/reserve! calls
    # cannot race each other into a lost update. The single call site both the live
    # settle!/reserve! path and the backfill task share.
    def self.recalculate!(quota, period_key)
      quota.with_lock do
        balance = find_or_create_by!(quota:, period_key:)
        balance.update!(
          consumed: quota.quota_usages.where(period_key:).sum(:amount),
          reserved: quota.quota_reservations.where(period_key:, status: 'held').sum(:amount),
          recalculated_at: Time.current
        )
        balance
      end
    end
  end
end
