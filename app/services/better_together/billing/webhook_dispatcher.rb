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
        return platform if platform && customer_on?(platform, normalized[:customer_ref])

        refuse(normalized, platform ? 'belongs to a customer of another platform' : 'matches no platform with billing configured')
      end

      # Pay's own handlers attribute an event through its customer. If that customer lives on a
      # different platform than the one resolved here, the two logs would disagree about who
      # the money belongs to, so the event is refused. An unknown customer is fine (it may not
      # have been created yet).
      def customer_on?(platform, customer_ref)
        return true if customer_ref.blank?

        customer = Pay::Customer.find_by(processor: @processor.to_s, processor_id: customer_ref.to_s)
        customer.nil? || customer.platform_id == platform.id
      end

      def refuse(normalized, reason)
        error = UnattributableWebhookError.new("#{@processor} event #{normalized[:event_id]} #{reason}")
        BetterTogether.report_error(error, context: { processor: @processor, event_id: normalized[:event_id] })
        raise error
      end
    end
  end
end
