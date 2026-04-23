# frozen_string_literal: true

module BetterTogether
  module C3
    # Scans for expired C3 balance locks and releases the reserved amounts.
    #
    # A lock expires when its expires_at timestamp passes and settlement
    # has not arrived (e.g. peer platform went offline, agreement was abandoned).
    # Expiry releases the locked C3 back to the payer — no value is ever lost.
    #
    # Scheduled every 15 minutes via config/sidekiq_scheduler.yml.
    # Each run processes all expired-but-not-yet-released locks in one pass.
    class ExpireBalanceLocksJob < BetterTogether::ApplicationJob
      queue_as :default

      def perform
        expired_locks = BetterTogether::C3::BalanceLock.expired

        expired_locks.find_each do |lock|
          lock.expire!
        rescue StandardError => e
          Rails.logger.error(
            "C3::ExpireBalanceLocksJob: failed to expire lock #{lock.id}: #{e.message}"
          )
        end
      end
    end
  end
end
