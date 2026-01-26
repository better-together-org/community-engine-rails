# frozen_string_literal: true

module BetterTogether
  module CalendarExport
    # Service for exporting Better Together events to Google Calendar API v3 JSON format
    class GoogleCalendarJson
      attr_reader :events

      def initialize(events)
        @events = Array.wrap(events)
      end

      def generate
        {
          kind: 'calendar#events',
          summary: 'Better Together Events',
          items: events.map { |event| event_to_json(event) }
        }.to_json
      end

      private

      def event_to_json(event)
        {
          kind: 'calendar#event',
          id: event.id,
          summary: event.name,
          description: event_description(event),
          start: event_datetime(event.starts_at, event.timezone),
          end: event_datetime(event.ends_at, event.timezone),
          creator: creator_json(event.creator),
          attendees: attendees_json(event),
          recurrence: recurrence_rules(event)
        }.compact
      end

      def event_description(event)
        return nil unless event.description.present?

        event.description.to_plain_text
      end

      def event_datetime(datetime, timezone)
        return nil unless datetime

        {
          dateTime: datetime.iso8601,
          timeZone: timezone || 'UTC'
        }
      end

      def creator_json(creator)
        return nil unless creator

        {
          email: creator.email,
          displayName: creator.name
        }
      end

      def attendees_json(event)
        return nil if event.event_attendances.empty?

        event.event_attendances.includes(:person).map do |attendance|
          {
            email: attendance.person.email,
            displayName: attendance.person.name,
            responseStatus: attendance_status(attendance.status)
          }
        end
      end

      def attendance_status(status)
        case status
        when 'going' then 'accepted'
        when 'interested' then 'tentative'
        else 'needsAction'
        end
      end

      def recurrence_rules(event)
        return nil unless event.recurrence&.schedule

        # Extract RRULE from the IceCube schedule
        # schedule.to_ical returns the full RRULE string
        [event.recurrence.schedule.to_ical]
      end
    end
  end
end
