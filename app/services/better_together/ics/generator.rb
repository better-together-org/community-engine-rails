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
        lines = header_lines + event_lines + footer_lines
        content = "#{lines.join("\r\n")}\r\n"
        Formatter.normalize_line_endings(content)
      end

      private

      attr_reader :schedulable

      # Generate VCALENDAR header with optional VTIMEZONE
      def header_lines
        lines = [
          'BEGIN:VCALENDAR',
          'VERSION:2.0',
          'PRODID:-//Better Together Community Engine//EN',
          'CALSCALE:GREGORIAN',
          'METHOD:PUBLISH'
        ]

        # Add VTIMEZONE component before VEVENT if event has a non-UTC timezone
        lines.concat(timezone_lines) if needs_timezone?

        lines << 'BEGIN:VEVENT'
        lines
      end

      # Generate VEVENT content
      def event_lines
        EventBuilder.new(schedulable).build
      end

      # Generate VCALENDAR footer
      def footer_lines
        ['END:VEVENT', 'END:VCALENDAR']
      end

      # Generate VTIMEZONE component if needed
      def timezone_lines
        return [] unless schedulable.respond_to?(:timezone) && schedulable.respond_to?(:starts_at)
        return [] unless schedulable.timezone.present? && schedulable.starts_at.present?

        TimezoneBuilder.new(schedulable.timezone, schedulable.starts_at).build
      end

      # Check if timezone component is needed
      def needs_timezone?
        schedulable.respond_to?(:timezone) &&
          schedulable.timezone.present? &&
          !['UTC', 'Etc/UTC'].include?(schedulable.timezone)
      end
    end
  end
end
