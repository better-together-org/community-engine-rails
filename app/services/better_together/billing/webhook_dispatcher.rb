# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pay webhook subscriber for one processor: normalizes the vendor event through
    # the adapter, attributes it to a platform, logs it once, and enqueues processing by
    # event id (never the payload).
    class WebhookDispatcher
      def initialize(processor)
        @processor = processor.to_sym
      end

      def call(vendor_event)
        adapter = BetterTogether::Billing.processor_adapter(@processor)
        return if adapter.blank?

        normalized = adapter.normalize_webhook(vendor_event)
        ingested = BetterTogether::Billing::EventIngest.call(
          processor: @processor, platform: platform_for(normalized), **normalized.slice(:event_id, :event_type, :payload, :occurred_at)
        )
        enqueue(ingested)
      end

      private

      # A duplicate delivery of an event that is still pending is enqueued again: the
      # first enqueue may have been lost (a queue outage), and a second job for an event
      # that is already in hand is a harmless no-op (see EventProcessor).
      def enqueue(ingested)
        return unless ingested.created || ingested.event.pending?

        BetterTogether::Billing::ProcessBillingEventJob.perform_later(ingested.event.id)
      end

      # Never guessed: with no platform that clearly owns the event, raise. Pay keeps
      # the delivery (its row is only deleted after successful processing), the error is
      # reported, and an operator can replay it once the mapping is fixed.
      def platform_for(normalized)
        platform = BetterTogether::Billing::Configuration.platform_for_webhook(
          @processor, platform_id: normalized[:platform_id], account_ref: normalized[:account_ref]
        )
        return platform if platform

        error = UnattributableWebhookError.new("#{@processor} event #{normalized[:event_id]} matches no platform with billing configured")
        BetterTogether.report_error(error, context: { processor: @processor, event_id: normalized[:event_id] })
        raise error
      end
    end
  end
end
