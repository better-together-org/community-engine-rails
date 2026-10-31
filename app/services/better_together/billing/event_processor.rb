# frozen_string_literal: true

module BetterTogether
  module Billing
    # Runs one logged event through its processor's adapter and records the outcome.
    #
    # Safe to call more than once for the same event (a duplicate delivery, a retried or
    # replayed job):
    # - an event whose outcome is already final is skipped;
    # - a job takes a short lease (`claimed_at`) under a row lock before it calls the
    #   adapter, so two jobs never run the processor at once;
    # - the outcome is written under a row lock, so a sweep or a replay that touched the
    #   row meanwhile cannot make the write fail with a stale-object error.
    # Adapters must still treat `process_event` as idempotent, because a job that fails
    # after the adapter acted is retried.
    class EventProcessor
      class MissingAdapterError < StandardError; end
      class MissingContextError < StandardError; end
      class RetryableError < StandardError; end

      def self.call(event) = new.call(event)

      def call(event)
        adapter, context = resolve(event)
        return unless claim(event)

        result = run(adapter, event, context)
        raise RetryableError, result.retry_reason.to_s if result.retry?

        result
      end

      private

      def resolve(event)
        adapter = BetterTogether::Billing.processor_adapter(event.processor)
        fail_with(event, MissingAdapterError.new("no billing processor registered for #{event.processor}")) unless adapter

        context = BetterTogether::Billing::Configuration.context_for(event.platform, event.processor)
        fail_with(event, MissingContextError.new("platform has no #{event.processor} billing configuration")) unless context

        [adapter, context]
      end

      def claim(event)
        event.with_lock do
          next false if event.terminal? || event.claimed?

          event.update!(attempt_count: event.attempt_count.to_i + 1, last_attempted_at: Time.current, claimed_at: Time.current)
          true
        end
      end

      def run(adapter, event, context)
        result = adapter.process_event(event:, context:)
        raise TypeError, "#{adapter.class}#process_event must return EventResult" unless result.is_a?(EventResult)

        record_outcome(event, result)
        notify(event)
        result
      rescue StandardError => e
        record_failure(event, e)
        raise
      end

      def record_outcome(event, result)
        event.with_lock do
          if result.retry?
            event.update!(processing_status: 'pending', error_message: result.retry_reason.to_s, claimed_at: nil)
          else
            event.update!(final_attributes(event, result))
          end
        end
      end

      # A final outcome also clears any dead-letter state: a late success after the sweep
      # gave up on the event must not leave it looking dead-lettered.
      def final_attributes(event, result)
        {
          processing_status: result.status.to_s, error_message: result.message&.to_s&.truncate(Event::ERROR_MESSAGE_LIMIT),
          processed_at: Time.current, claimed_at: nil, dead_lettered_at: nil, dead_letter_reason: nil
        }.merge(reported_references(event, result))
      end

      # What the adapter says the outcome was and who and what it concerned, falling back
      # to what the event already had.
      def reported_references(event, result)
        {
          billable_owner: result.billable_owner || event.billable_owner, beneficiary: result.beneficiary || event.beneficiary,
          subject: result.subject || event.subject, outcome_kind: result.outcome_kind&.to_s || event.outcome_kind
        }
      end

      # Tells the people the outcome concerns, once per event: a replay of the same event finds the
      # receipts already there. Kinds core does not announce are left alone.
      def notify(event)
        event.reload
        kind = event.outcome_kind
        return unless kind && event.subject && Notifications::Catalog.kind?(kind) && event.terminal?

        Notifications.deliver(kind, subject: event.subject, dedupe_key: "event:#{event.id}")
      end

      def fail_with(event, error)
        record_failure(event, error)
        raise error
      end

      def record_failure(event, error)
        # A write that just failed validation leaves unsaved changes on the record, and a
        # locked write refuses a record with unsaved changes, so start from what is stored.
        event.reload.with_lock do
          event.update!(processing_status: 'failed', error_message: Event.safe_error_message(error), claimed_at: nil) unless event.terminal?
        end
      rescue StandardError => e
        Rails.logger.error("[billing] could not record failure for event #{event.id}: #{e.class}")
      end
    end
  end
end
