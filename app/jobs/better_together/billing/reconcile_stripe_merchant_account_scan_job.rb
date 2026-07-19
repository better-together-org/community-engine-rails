# frozen_string_literal: true

module BetterTogether
  module Billing
    # Periodically scans connected Stripe merchant accounts and enqueues focused
    # refresh jobs so local capability/status snapshots can self-heal after
    # missed or out-of-order webhook delivery.
    class ReconcileStripeMerchantAccountScanJob < BetterTogether::ApplicationJob
      LOCK_KEY = 'bt:billing:stripe_merchant_account_scan_lock'
      LOCK_TTL = 30.minutes.to_i

      queue_as :maintenance

      # rubocop:disable Metrics/MethodLength
      def perform(account_limit: nil)
        acquired = Sidekiq.redis { |redis| redis.set(LOCK_KEY, job_id, nx: true, ex: LOCK_TTL) }
        return unless acquired

        begin
          scope = eligible_merchant_accounts
          scope = scope.limit(account_limit) if account_limit.present?

          scope.find_each do |merchant_account|
            BetterTogether::Billing::ReconcileStripeMerchantAccountJob.perform_later(merchant_account.id)
          rescue StandardError => e
            Rails.logger.error(
              "Failed to enqueue Stripe merchant-account reconciliation for #{merchant_account.id}: #{e.message}"
            )
          end
        ensure
          release_lock_if_owner
        end
      end
      # rubocop:enable Metrics/MethodLength

      private

      def eligible_merchant_accounts
        BetterTogether::Billing::MerchantAccount.where(provider: 'stripe_connect')
                                                .where.not(external_account_id: [nil, ''])
      end

      RELEASE_LOCK_SCRIPT = <<~LUA
        if redis.call("get", KEYS[1]) == ARGV[1] then
          return redis.call("del", KEYS[1])
        else
          return 0
        end
      LUA
      private_constant :RELEASE_LOCK_SCRIPT

      def release_lock_if_owner
        Sidekiq.redis { |redis| redis.call('EVAL', RELEASE_LOCK_SCRIPT, 1, LOCK_KEY, job_id) }
      end
    end
  end
end
