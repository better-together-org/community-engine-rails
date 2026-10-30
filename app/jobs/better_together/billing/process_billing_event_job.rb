# frozen_string_literal: true

module BetterTogether
  module Billing
    # Processes a logged billing event off the request thread. The argument is the
    # event id only, so webhook payloads never enter the job queue or its logs.
    class ProcessBillingEventJob < BetterTogether::ApplicationJob
      queue_as :default

      discard_on ActiveRecord::RecordNotFound
      retry_on StandardError, wait: :polynomially_longer, attempts: BetterTogether::Billing::Event::MAX_ATTEMPTS
      retry_on BetterTogether::Billing::EventProcessor::RetryableError, wait: 30.seconds,
                                                                        attempts: BetterTogether::Billing::Event::MAX_ATTEMPTS

      def perform(event_id)
        BetterTogether::Billing::EventProcessor.call(BetterTogether::Billing::Event.find(event_id))
      end
    end
  end
end
