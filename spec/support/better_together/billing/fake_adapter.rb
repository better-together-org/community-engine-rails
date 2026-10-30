# frozen_string_literal: true

module BetterTogether
  module Billing
    # In-memory processor used by core specs so billing never needs a vendor gem.
    class FakeAdapter < ProcessorAdapter
      attr_reader :calls, :capabilities

      def initialize(capabilities: %i[checkout], processor: :fake)
        super()
        @capabilities = capabilities
        @processor = processor
        @calls = []
      end

      def processor_name = @processor
      def webhook_event_types = ["#{@processor}.invoice.paid"]
      def sanitize_payload(payload) = payload.to_h.slice('id', 'type')

      def create_checkout_session(context:, **args)
        @calls << [:create_checkout_session, context, args]
        { url: "https://fake.test/checkout/#{args[:idempotency_key]}" }
      end

      def sync_checkout_session(context:, **args)
        @calls << [:sync_checkout_session, context, args]
        { status: 'paid' }
      end
    end
  end
end
