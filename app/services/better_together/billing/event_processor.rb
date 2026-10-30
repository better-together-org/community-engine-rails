# frozen_string_literal: true

module BetterTogether
  module Billing
    # Runs one logged event through its processor's adapter and records the outcome.
    class EventProcessor
      class MissingAdapterError < StandardError; end
      class RetryableError < StandardError; end

      def self.call(event) = new.call(event)

      def call(event)
        adapter = BetterTogether::Billing.processor_adapter(event.processor)
        raise MissingAdapterError, "no billing processor registered for #{event.processor}" unless adapter

        event.update!(attempt_count: event.attempt_count.to_i + 1, last_attempted_at: Time.current)
        result = process(adapter, event)
        persist_result(event, result)
        raise RetryableError, result.retry_reason.to_s if result.retry?

        result
      end

      private

      def process(adapter, event)
        result = adapter.process_event(event:)
        raise TypeError, "#{adapter.class}#process_event must return EventResult" unless result.is_a?(EventResult)

        result
      rescue StandardError => e
        persist_failure(event, e)
        raise
      end

      def persist_result(event, result)
        if result.retry?
          event.update!(processing_status: 'pending', error_message: result.retry_reason.to_s)
          return
        end

        event.update!(
          processing_status: result.status.to_s, billable_owner: result.billable_owner || event.billable_owner,
          beneficiary: result.beneficiary || event.beneficiary, error_message: result.message&.to_s&.truncate(Event::ERROR_MESSAGE_LIMIT),
          processed_at: Time.current
        )
      end

      def persist_failure(event, error)
        event.update!(processing_status: 'failed', error_message: Event.safe_error_message(error))
      rescue StandardError => e
        Rails.logger.error("[billing] could not record failure for event #{event.id}: #{e.class}")
      end
    end
  end
end
