# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pay webhook subscriber for one processor: normalizes the vendor event through
    # the adapter, logs it once, and enqueues processing by event id (never the payload).
    class WebhookDispatcher
      def initialize(processor)
        @processor = processor.to_sym
      end

      def call(vendor_event)
        adapter = BetterTogether::Billing.processor_adapter(@processor)
        return if adapter.blank?

        ingested = BetterTogether::Billing::EventIngest.call(processor: @processor, **adapter.normalize_webhook(vendor_event))
        BetterTogether::Billing::ProcessBillingEventJob.perform_later(ingested.event.id) if ingested.created
      end
    end
  end
end
