# frozen_string_literal: true

module BetterTogether
  module Billing
    # Processes a logged billing event off the request thread. The argument is the
    # event id only, so webhook payloads never enter the job queue or its logs.
    class ProcessBillingEventJob < ApplicationJob
      # A "prerequisite is missing" result (for example Pay has not synced the
      # subscription yet) can take a while to clear, so it backs off over about an hour
      # rather than retrying every half minute.
      RETRY_WAITS = [30.seconds, 2.minutes, 10.minutes, 30.minutes].freeze

      discard_on ActiveRecord::RecordNotFound
      retry_on StandardError, wait: :polynomially_longer, attempts: BetterTogether::Billing::Event::MAX_ATTEMPTS
      retry_on BetterTogether::Billing::EventProcessor::RetryableError,
               wait: ->(executions) { RETRY_WAITS.fetch(executions - 1, RETRY_WAITS.last) },
               attempts: BetterTogether::Billing::Event::MAX_ATTEMPTS

      def perform(event_id)
        BetterTogether::Billing::EventProcessor.call(BetterTogether::Billing::Event.find(event_id))
      end
    end
  end
end
