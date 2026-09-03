# frozen_string_literal: true

module BetterTogether
  module Billing
    # Reconstructs and processes Stripe webhook payloads off the request thread.
    class ProcessStripeEventJob < BetterTogether::ApplicationJob
      queue_as :default

      retry_on StandardError, wait: :polynomially_longer, attempts: 10

      def perform(event_payload)
        event = Stripe::Event.construct_from(event_payload.deep_symbolize_keys)
        BetterTogether::Billing::StripeEventProcessor.new.call(event)
      end
    end
  end
end
