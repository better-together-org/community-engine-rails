# frozen_string_literal: true

module BetterTogether
  module Billing
    # In-memory processor used by core specs so billing never needs a vendor gem.
    class FakeAdapter < ProcessorAdapter
      attr_reader :calls, :capabilities

      def initialize(capabilities: %i[checkout])
        super()
        @capabilities = capabilities
        @calls = []
      end

      def processor_name = :fake
      def webhook_event_types = ['fake.invoice.paid']
      def sanitize_payload(payload) = payload.to_h.slice('id', 'type')

      def create_checkout_session(**args)
        @calls << [:create_checkout_session, args]
        { url: "https://fake.test/checkout/#{args[:idempotency_key]}" }
      end

      def sync_checkout_session(**args)
        @calls << [:sync_checkout_session, args]
        { status: 'paid' }
      end
    end
  end
end
