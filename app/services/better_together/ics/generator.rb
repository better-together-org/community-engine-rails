# frozen_string_literal: true

module BetterTogether
  module Ics
    # Main service for generating ICS (iCalendar) files
    # Coordinates the assembly of VCALENDAR, VTIMEZONE, and VEVENT components
    #
    # @example Generate ICS for a single event
    #   generator = BetterTogether::Ics::Generator.new(event)
    #   ics_content = generator.generate
    #
    # @example Generate ICS for multiple events (future enhancement)
    #   generator = BetterTogether::Ics::Generator.new([event1, event2])
    #   ics_content = generator.generate
    class Generator
      def initialize(schedulable)
        @schedulable = schedulable
      end

      # Generate complete ICS file content
      # @return [String] ICS-formatted calendar data with proper line endings
      def generate
        lines = header_lines + all_events_lines + footer_lines
        content = "#{lines.join("\r\n")}\r\n"
        Formatter.normalize_line_endings(content)
      end

      private

      attr_reader :schedulable

      # Get array of schedulables (single or multiple)
      def schedulables
        schedulable.is_a?(Array) ? schedulable : [schedulable]
      end

      # Generate VCALENDAR header with optional VTIMEZONE
      def header_lines
        lines = [
          'BEGIN:VCALENDAR',
          'VERSION:2.0',
          'PRODID:-//Better Together Community Engine//EN',
          'CALSCALE:GREGORIAN',
          'METHOD:PUBLISH'
        ]

        # Add all unique VTIMEZONE components before events
        lines.concat(all_timezone_lines)

        lines
      end

      # Generate all VEVENT components
      def all_events_lines
        schedulables.flat_map do |event|
          ['BEGIN:VEVENT'] + EventBuilder.new(event).build + ['END:VEVENT']
        end
      end

      # Generate VCALENDAR footer
      def footer_lines
        ['END:VCALENDAR']
      end

      # Generate all unique VTIMEZONE components
      def all_timezone_lines
        unique_timezones.flat_map do |timezone|
          reference_event = schedulables.find { |e| e.timezone == timezone }
          TimezoneBuilder.new(timezone, reference_event.starts_at).build
        end
      end

      # Get unique non-UTC timezones from all schedulables
      def unique_timezones
        schedulables.filter_map do |event|
          event_timezone(event)
        end.uniq
      end

      # Extract timezone from event if valid
      def event_timezone(event)
        return unless event.respond_to?(:timezone) && event.respond_to?(:starts_at)
        return unless event.timezone.present? && event.starts_at.present?
        return if utc_timezone?(event.timezone)

        event.timezone
      end

      # Check if timezone is UTC
      def utc_timezone?(timezone)
        ['UTC', 'Etc/UTC'].include?(timezone)
      end
    end
  end
end
