# frozen_string_literal: true

module BetterTogether
  module Billing
    # Gives a job to events left pending with nobody working on them (an enqueue that was lost,
    # a queue that was flushed). Safe to repeat: processing takes a lease and skips final outcomes.
    class EnqueueStuckBillingEventsJob < ApplicationJob
      def perform
        # Only ids are loaded here, so the sweep does not decrypt any payload.
        BetterTogether::Billing::Event.stuck_pending.pluck(:id).each do |event_id|
          BetterTogether::Billing::ProcessBillingEventJob.perform_later(event_id)
        rescue StandardError => e
          Rails.logger.error("[billing] could not re-enqueue event #{event_id}: #{e.class}")
        end
      end
    end
  end
end
