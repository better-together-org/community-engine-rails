# frozen_string_literal: true

module BetterTogether
  module Billing
    # What the operator rake tasks print and do with billing events. Output carries ids,
    # states and counts only: the payload and the error text are encrypted and stay out of it.
    module EventOperations
      module_function

      STATES = %w[failed dead_lettered all].freeze

      # Failed and dead-lettered events, newest first (200 at most), one line each.
      def list(state)
        raise ArgumentError, 'State must be failed, dead_lettered or all.' unless STATES.include?(state)

        events = Event.problematic.newest_first
        events = events.where(processing_status: state) unless state == 'all'
        events.limit(200).map { |event| line(event) }.presence || ['No failed or dead-lettered billing events.']
      end

      def line(event)
        [event.id, event.platform_id, event.processor, event.event_type, event.processing_status, "attempts=#{event.attempt_count}",
         "replays=#{event.replay_count}", event.last_attempted_at&.iso8601 || '-'].join('  ')
      end

      def detail(event)
        [
          line(event),
          "event_id: #{event.event_id}",
          "dead_letter_reason: #{event.dead_letter_reason || '-'}",
          "dead_lettered_at: #{event.dead_lettered_at&.iso8601 || '-'}",
          "last_replayed_at: #{event.last_replayed_at&.iso8601 || '-'}",
          "replayable: #{replayable?(event)}"
        ]
      end

      # One report line per event. Without apply nothing changes.
      def replay(events, apply:, operator_id:)
        operator = apply ? operator_for(operator_id) : nil
        lines = events.map { |event| replay_line(event, apply:, operator:) }
        lines << (apply ? 'Done.' : 'Dry run: nothing was changed. Run again with APPLY=1 and OPERATOR=<person id> to replay.')
      end

      def replay_line(event, apply:, operator:)
        return "#{event.id}  would replay  #{event.processing_status}" if !apply && replayable?(event)
        return "#{event.id}  skipped  #{event.processing_status}" unless apply

        result = ReplayEvent.call(billing_event: event, requested_by: operator)
        "#{event.id}  #{result.enqueued ? 'replayed' : "refused (#{result.reason})"}"
      end

      def replayable?(event)
        event.problematic? && event.replayable_payload?
      end

      # A person who manages the host platform; anyone else cannot change billing events.
      def operator_for(operator_id)
        raise ArgumentError, 'Set OPERATOR=<person id> to apply.' if operator_id.blank?

        person = BetterTogether::Person.find(operator_id)
        host = BetterTogether::Platform.find_by(host: true)
        raise ArgumentError, 'The operator must manage the host platform.' unless host && person.permitted_to?(:manage_platform, host)

        person
      end
    end
  end
end
