# frozen_string_literal: true

module BetterTogether
  module Billing
    # Validates and re-enqueues a dead-lettered event for operator replay.
    class ReplayEvent
      Result = Struct.new(:enqueued, :reason, keyword_init: true)

      def self.call(...) = new.call(...)

      def call(billing_event:, requested_by:)
        return rejected(:not_dead_lettered) unless billing_event.dead_lettered?
        return rejected(:payload_unavailable) unless billing_event.replayable_payload?
        return rejected(:unsupported_processor) unless BetterTogether::Billing.processor_names.include?(billing_event.processor.to_sym)

        billing_event.mark_replay_requested!(requested_by:)
        BetterTogether::Billing::ProcessBillingEventJob.perform_later(billing_event.id)
        Result.new(enqueued: true, reason: :enqueued)
      end

      private

      def rejected(reason) = Result.new(enqueued: false, reason:)
    end
  end
end
