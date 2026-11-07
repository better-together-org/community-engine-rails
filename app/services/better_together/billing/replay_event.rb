# frozen_string_literal: true

module BetterTogether
  module Billing
    # Validates and re-enqueues a dead-lettered event for operator replay.
    class ReplayEvent
      Result = Struct.new(:enqueued, :reason, keyword_init: true)

      def self.call(...) = new.call(...)

      def call(billing_event:, requested_by:)
        reason = refusal_reason(billing_event)
        return rejected(reason) if reason

        billing_event.mark_replay_requested!(requested_by:)
        BetterTogether::Billing::ProcessBillingEventJob.perform_later(billing_event.id)
        Result.new(enqueued: true, reason: :enqueued)
      end

      private

      def rejected(reason) = Result.new(enqueued: false, reason:)

      # Why this event cannot be replayed, or nil when it can.
      def refusal_reason(billing_event)
        return :not_dead_lettered unless billing_event.dead_lettered?
        return :payload_unavailable unless billing_event.replayable_payload?
        return :unsupported_processor unless BetterTogether::Billing.processor_names.include?(billing_event.processor.to_sym)

        :platform_not_configured unless
          BetterTogether::Billing::Configuration.context_for(billing_event.platform, billing_event.processor)
      end
    end
  end
end
