# frozen_string_literal: true

module BetterTogether
  module Billing
    # Base for a method that is a ledger inside Community Engine rather than a vendor or a
    # hand-off (store credit). Nothing is confirmed by a seller and nothing is received: core
    # moves the money itself, inside the transaction that places the order, so there are no
    # instructions, no webhooks and no offline payment.
    #
    # Subclasses set `processor_name`. They are enabled per platform through ProcessorSetting
    # like any local method, but never carry instructions.
    class InternalProcessorAdapter < ProcessorAdapter
      def capabilities = []
      def settlement_kind = :internal
      def recurring_mode = :manual
      def fee_collectible? = false
      def webhook_event_types = []

      # Nothing for a buyer to be told about how to pay: the credit is spent for them.
      def instructions_for(setting: nil, context: nil, order: nil) = {} # rubocop:disable Lint/UnusedMethodArgument

      def normalize_webhook(_vendor_event) = raise(ArgumentError, "#{processor_name} does not receive webhooks")

      def process_event(event:, context:) # rubocop:disable Lint/UnusedMethodArgument
        EventResult.new(status: :processed, outcome_kind: event.outcome_kind)
      end

      def sanitize_payload(payload) = payload.to_h.slice('id', 'type', 'outcome_kind')
    end
  end
end
