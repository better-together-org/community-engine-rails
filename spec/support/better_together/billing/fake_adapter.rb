# frozen_string_literal: true

module BetterTogether
  module Billing
    # In-memory processor used by core specs so billing never needs a vendor gem.
    class FakeAdapter < ProcessorAdapter
      attr_reader :calls, :capabilities

      # `settlement:` and `countries:` let specs stand in for a manual (offline) method.
      def initialize(capabilities: %i[checkout], processor: :fake, settlement: :remote, countries: nil)
        super()
        @capabilities = capabilities
        @processor = processor
        @settlement = settlement
        @countries = countries
        @calls = []
      end

      def settlement_kind = @settlement
      def supported_countries = @countries
      def recurring_mode = @settlement == :manual ? :manual : super
      def instruction_fields = supports?(:offline_settlement) ? [InstructionField.new(name: :note, type: :text)] : []

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

      def refund(context:, **args)
        @calls << [:refund, context, args]
        { reference: "re_#{args[:idempotency_key]}" }
      end

      def transfer(context:, **args)
        @calls << [:transfer, context, args]
        { reference: "tr_#{args[:idempotency_key]}" }
      end

      def instructions_for(context:, setting:, order:)
        @calls << [:instructions_for, context, order]
        { 'note' => setting.to_h['note'] }
      end
    end
  end
end
