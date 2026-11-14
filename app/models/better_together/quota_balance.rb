# frozen_string_literal: true

module BetterTogether
  # Materialized consumed/reserved totals for one Quota and one period, updated under
  # a row lock whenever BetterTogether::Quotas writes a usage or reservation, a cache
  # of quota_usages, never a source of truth on its own.
  class QuotaBalance < PlatformRecord
    belongs_to :quota

    validates :period_key, presence: true
    validates :quota_id, uniqueness: { scope: :period_key }
    validates :consumed, :reserved, numericality: { only_integer: true }

    class << self
      # Hot path for a newly written usage row: adds its amount to `consumed` under a
      # row lock on the owning Quota, so concurrent writers cannot lose an update.
      # Constant-time, unlike re-summing the owner's whole (cumulative) ledger on
      # every attachment.
      def apply_usage!(quota, period_key, amount)
        quota.with_lock do
          balance = find_or_create_by!(quota:, period_key:)
          balance.update!(consumed: balance.consumed + amount, recalculated_at: Time.current)
          balance
        end
      end

      # Recomputes only `reserved`, from the reservations still held and unexpired.
      # That set stays small (settled/expired rows drop out), so this is cheap.
      def refresh_reserved!(quota, period_key)
        quota.with_lock do
          balance = find_or_create_by!(quota:, period_key:)
          balance.update!(reserved: held_reserved(quota, period_key), recalculated_at: Time.current)
          balance
        end
      end

      # Full recompute of consumed/reserved for one quota+period from the ledger.
      # A repair/backfill tool, not the per-write path: it sums the whole period.
      def recalculate!(quota, period_key)
        quota.with_lock do
          balance = find_or_create_by!(quota:, period_key:)
          balance.update!(
            consumed: quota.quota_usages.where(period_key:).sum(:amount),
            reserved: held_reserved(quota, period_key),
            recalculated_at: Time.current
          )
          balance
        end
      end

      private

      # Expired holds are excluded here rather than by a sweeper (deferred to a later
      # phase), so an abandoned direct upload stops counting once its TTL passes.
      def held_reserved(quota, period_key)
        quota.quota_reservations
             .where(period_key:, status: 'held')
             .where(QuotaReservation.arel_table[:expires_at].gt(Time.current))
             .sum(:amount)
      end
    end
  end
end
