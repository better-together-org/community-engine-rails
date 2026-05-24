# frozen_string_literal: true

module BetterTogether
  module Billing
    # Periodically scans Stripe-backed billable owners and enqueues focused
    # reconciliation jobs so hosted billing state can self-heal after missed or
    # out-of-order webhook delivery.
    class ReconcileStripeBillableOwnerBillingScanJob < BetterTogether::ApplicationJob
      LOCK_KEY = 'bt:billing:stripe_billable_owner_scan_lock'
      LOCK_TTL = 30.minutes.to_i

      queue_as :maintenance

      # rubocop:disable Metrics/MethodLength
      def perform(owner_limit: nil)
        acquired = Sidekiq.redis { |redis| redis.set(LOCK_KEY, job_id, nx: true, ex: LOCK_TTL) }
        return unless acquired

        begin
          eligible_owner_rows(owner_limit:).each do |owner_type, owner_id|
            BetterTogether::Billing::ReconcileStripeBillableOwnerBillingJob.perform_later(owner_type, owner_id)
          rescue StandardError => e
            Rails.logger.error(
              "Failed to enqueue Stripe billable-owner reconciliation for #{owner_type}/#{owner_id}: #{e.message}"
            )
          end
        ensure
          release_lock_if_owner
        end
      end
      # rubocop:enable Metrics/MethodLength

      private

      def eligible_owner_rows(owner_limit:)
        Pay::Customer.where(processor: 'stripe')
                     .where.not(processor_id: [nil, ''])
                     .where(owner_type: BetterTogether::Billing::Event::SUPPORTED_OWNER_TYPES)
                     .distinct
                     .limit(owner_limit)
                     .pluck(:owner_type, :owner_id)
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
