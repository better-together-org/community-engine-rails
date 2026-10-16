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

      def normalize_webhook(vendor_event)
        { event_id: vendor_event['id'], event_type: vendor_event['type'], payload: vendor_event.to_h }
      end

      # The event payload's 'outcome' picks the result; 'boom' raises.
      def process_event(event:)
        @calls << [:process_event, event.id]
        outcome = event.payload['outcome'].to_s
        raise 'fake processor failure' if outcome == 'boom'

        EventResult.new(status: outcome.presence || 'processed', retry_reason: ('prerequisite_missing' if outcome == 'retry'))
      end

      def sync_plan(plan:)
        @calls << [:sync_plan, plan.id]
      end

      # Price ids containing "missing" are unknown; "boom" simulates a lookup failure.
      def verify_price(processor_price_id:) # rubocop:disable Naming/PredicateMethod
        raise 'lookup failed' if processor_price_id.to_s.include?('boom')

        processor_price_id.to_s.exclude?('missing')
      end

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
