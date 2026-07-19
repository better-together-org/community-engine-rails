# frozen_string_literal: true

module BetterTogether
  module Billing
    # Validates and re-enqueues a dead-lettered Stripe billing event for manual replay.
    class ReplayStripeBillingEvent
      ReplayResult = Struct.new(:enqueued, :reason, keyword_init: true)

      def call(billing_event:, requested_by:)
        return ReplayResult.new(enqueued: false, reason: :not_dead_lettered) unless billing_event.dead_lettered?
        return ReplayResult.new(enqueued: false, reason: :payload_unavailable) unless billing_event.replayable_payload?
        return ReplayResult.new(enqueued: false, reason: :unsupported_processor) unless billing_event.processor == 'stripe'

        billing_event.mark_replay_requested!(requested_by:)
        BetterTogether::Billing::ProcessStripeEventJob.perform_later(billing_event.payload.deep_dup)

        ReplayResult.new(enqueued: true, reason: :enqueued)
      end
    end
  end
end
