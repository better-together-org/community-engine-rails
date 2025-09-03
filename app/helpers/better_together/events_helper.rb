# frozen_string_literal: true

module BetterTogether
  # View helpers for events
  module EventsHelper
    # Returns a formatted time range for an event
    # If only a start time is present, it is formatted by itself.
    # If the event ends on the same day, the end time is shown without the date.
    # Otherwise, both start and end are fully formatted.
    def event_time_range(event, format: :event)
      return unless event&.starts_at

      start_time = l(event.starts_at, format: format)
      return start_time unless event.ends_at

      end_time = if event.starts_at.to_date == event.ends_at.to_date
                   l(event.ends_at, format: '%-I:%M %p')
                 else
                   l(event.ends_at, format: format)
                 end

      "#{start_time} - #{end_time}"
    end

    # Builds a location string from the event's location and its associated address
    def event_location(event)
      location = event&.location
      return unless location

      parts = []
      parts << location.name if location.respond_to?(:name) && location.name.present?
      parts << location.location.to_s if location.respond_to?(:location) && location.location.present?

      parts.compact.join(', ').presence
    end

    # Return hosts for an event that the current user is authorized to view.
    # Keeps view markup small and centralizes the policy logic for testing.
    def visible_event_hosts(event)
      return [] unless event.respond_to?(:event_hosts)

      event.event_hosts.map { |eh| eh.host if policy(eh.host).show? }.compact
    end
  end
end
