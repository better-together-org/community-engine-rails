# frozen_string_literal: true

module BetterTogether
  module Billing
    # Promotes events whose retries are exhausted, or that made no progress, into the dead-letter state.
    class DeadLetterStaleBillingEventsJob < BetterTogether::ApplicationJob
      queue_as :maintenance

      def perform
        BetterTogether::Billing::Event.eligible_for_dead_lettering.find_each do |billing_event|
          billing_event.dead_letter!(reason: reason_for(billing_event))
        end
      end

      private

      def reason_for(billing_event)
        billing_event.attempt_count.to_i >= BetterTogether::Billing::Event::MAX_ATTEMPTS ? 'retries_exhausted' : 'stale_unresolved_drift'
      end
    end
  end
end
