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

      # A vendor event may name the platform it is for ('platform_id'), the processor
      # account it came from ('account'), and when it happened ('created').
      def normalize_webhook(vendor_event)
        {
          event_id: vendor_event['id'], event_type: vendor_event['type'], payload: vendor_event.to_h,
          platform_id: vendor_event['platform_id'], account_ref: vendor_event['account'],
          occurred_at: (Time.zone.at(vendor_event['created']) if vendor_event['created'])
        }.compact
      end

      # The event payload's 'outcome' picks the result; 'boom' raises.
      def process_event(event:, context:)
        @calls << [:process_event, event.id, context]
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
