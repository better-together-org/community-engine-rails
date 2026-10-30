# frozen_string_literal: true

module BetterTogether
  module Billing
    # Promotes events whose retries are exhausted, or that made no progress, into the
    # dead-letter state. One event at a time, each under a row lock that re-checks the
    # event is still stuck, so a job that finished it meanwhile is never overwritten, and
    # one bad row does not stop the sweep.
    class DeadLetterStaleBillingEventsJob < ApplicationJob
      def perform
        # Only ids are loaded here, so the sweep does not decrypt any payload.
        BetterTogether::Billing::Event.eligible_for_dead_lettering.select(:id).find_each do |row|
          dead_letter(row.id)
        end
      end

      private

      def dead_letter(event_id)
        BetterTogether::Billing::Event.find(event_id).dead_letter_if_stale!
      rescue StandardError => e
        Rails.logger.error("[billing] could not dead-letter event #{event_id}: #{e.class}")
      end
    end
  end
end
