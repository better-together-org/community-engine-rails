# frozen_string_literal: true

module BetterTogether
  module Billing
    # Promotes repeatedly failing or stale unresolved billing events into a dead-letter state.
    class DeadLetterStaleBillingEventsJob < BetterTogether::ApplicationJob
      queue_as :maintenance

      def perform
        BetterTogether::Billing::Event.eligible_for_dead_lettering.find_each do |billing_event|
          billing_event.dead_letter!(reason: dead_letter_reason_for(billing_event))
        end
      end

      private

      def dead_letter_reason_for(billing_event)
        return 'repeated_failures' if billing_event.attempt_count.to_i >= BetterTogether::Billing::Event::REPEATED_FAILURE_ATTEMPT_THRESHOLD

        'stale_unresolved_drift'
      end
    end
  end
end
