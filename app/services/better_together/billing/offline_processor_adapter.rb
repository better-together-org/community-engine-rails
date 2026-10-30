# frozen_string_literal: true

module BetterTogether
  module Billing
    # Base for payment methods that happen outside anything the platform can see: cash,
    # a cheque, an e-transfer. There is no vendor and no webhook. The seller says when the
    # money arrived, and core owns the state machine, so an adapter only DESCRIBES the
    # method: what the seller fills in so buyers know how to pay, where it works, and
    # which checks apply to what they entered.
    #
    # Subclasses set `processor_name` and `instruction_fields`, and may narrow
    # `supported_countries` / `supported_currencies`, add `settings_errors` rules, or offer
    # a choice of `grant_on_options`. See docs/billing/payment_methods.md.
    class OfflineProcessorAdapter < ProcessorAdapter
      # Core logs events for these methods itself (a payment confirmed, a setting changed)
      # and processes them through the usual job; there is nothing to receive.
      def capabilities = %i[offline_settlement]
      def settlement_kind = :manual
      def recurring_mode = :manual
      def fee_collectible? = false
      def webhook_event_types = []

      # When the buyer's access starts: `confirmed` (the seller says the money arrived), or
      # for a cheque `received` or `cleared`. The first option is the default.
      def grant_on_options = %w[confirmed]
      def default_grant_on = grant_on_options.first

      # { field => error code } for the values a seller entered, to be shown on the form.
      # Required fields first; subclasses add rules that span fields.
      def settings_errors(values)
        values = values.to_h.stringify_keys
        instruction_fields.select(&:required?).each_with_object({}) do |field, errors|
          errors[field.name.to_s] = :blank if values[field.name.to_s].to_s.strip.empty?
        end
      end

      # What the buyer is shown: field name => value, in the declared order, from the
      # seller's saved settings. Never log it or put it in an email.
      def instructions_for(setting:, context: nil, order: nil) # rubocop:disable Lint/UnusedMethodArgument
        values = (setting.respond_to?(:settings) ? setting.settings : setting).to_h.stringify_keys
        instruction_fields.to_h { |field| [field.name.to_s, values[field.name.to_s].to_s.strip.presence] }.compact
      end

      # Core writes these events and has nothing to receive, so the event pipeline hooks are
      # trivial: whatever core logged was already decided.
      def normalize_webhook(_vendor_event) = raise(ArgumentError, "#{processor_name} does not receive webhooks")

      def process_event(event:, context:) # rubocop:disable Lint/UnusedMethodArgument
        EventResult.new(status: :processed, outcome_kind: event.outcome_kind)
      end

      # Keeps identifiers and the neutral outcome. The rest of the payload may name the
      # people involved, so it is dropped.
      def sanitize_payload(payload) = payload.to_h.slice('id', 'type', 'outcome_kind')
    end
  end
end
