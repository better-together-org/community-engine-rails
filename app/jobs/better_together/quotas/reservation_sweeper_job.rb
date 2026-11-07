# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Reaps expired `held` quota reservations. Phase 5a deliberately never ran this -
    # QuotaBalance already excludes expired holds from `reserved` on every read (see
    # QuotaBalance.held_reserved), so nothing was ever wrong without it. This job only
    # stops the quota_reservations table from accumulating stale `held` rows forever,
    # same purpose as FederationAccessTokenPurgeJob for its own table. Designed to run
    # every 5 minutes (see config/sidekiq_scheduler.yml) - reserve!'s default ttl is
    # 5.minutes, so reservations go stale on roughly that cadence.
    class ReservationSweeperJob < ApplicationJob
      queue_as :maintenance

      def perform
        touched = Set.new
        expired_reservations.find_each do |reservation|
          reservation.update!(status: 'expired')
          touched << [reservation.quota_id, reservation.period_key]
        end

        touched.each do |quota_id, period_key|
          BetterTogether::QuotaBalance.refresh_reserved!(Quota.find(quota_id), period_key)
        end

        Rails.logger.info "[ReservationSweeperJob] Expired #{touched.size} reservation group(s)"
      end

      private

      def expired_reservations
        BetterTogether::QuotaReservation.status_held
                                        .where(QuotaReservation.arel_table[:expires_at].lt(Time.current))
      end
    end
  end
end
