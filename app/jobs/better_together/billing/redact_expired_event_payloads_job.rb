# frozen_string_literal: true

module BetterTogether
  module Billing
    # Redacts retained Stripe event payloads after the short replay window
    # expires so billing audit logs keep identifiers without indefinite raw data.
    class RedactExpiredEventPayloadsJob < BetterTogether::ApplicationJob
      LOCK_KEY = 'bt:billing:redact_expired_event_payloads_lock'
      LOCK_TTL = 30.minutes.to_i
      BATCH_SIZE = 100

      queue_as :maintenance

      def perform(batch_size: BATCH_SIZE)
        acquired = Sidekiq.redis { |redis| redis.set(LOCK_KEY, job_id, nx: true, ex: LOCK_TTL) }
        return unless acquired

        begin
          BetterTogether::Billing::Event.payload_retention_expired.find_in_batches(batch_size:) do |events|
            events.each do |event|
              event.redact_payload!
            rescue StandardError => e
              Rails.logger.error("Failed to redact billing event payload #{event.id}: #{e.message}")
            end
          end
        ensure
          release_lock_if_owner
        end
      end

      private

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
