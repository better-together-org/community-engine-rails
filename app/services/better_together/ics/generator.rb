# frozen_string_literal: true

require 'icalendar'

module BetterTogether
  module Ics
    # Main service for generating ICS (iCalendar) files
    # Coordinates the assembly of VCALENDAR, VTIMEZONE, and VEVENT components
    # Uses the icalendar gem for robust ICS generation
    #
    # @example Generate ICS for a single event
    #   generator = BetterTogether::Ics::Generator.new(event)
    #   ics_content = generator.generate
    #
    # @example Generate ICS for multiple events
    #   generator = BetterTogether::Ics::Generator.new([event1, event2])
    #   ics_content = generator.generate
    class Generator
      def initialize(schedulable)
        @events = Array.wrap(schedulable)
      end

      # Generate complete ICS file content
      # @return [String] ICS-formatted calendar data with proper line endings
      def generate
        calendar = Icalendar::Calendar.new
        calendar.prodid = '-//Better Together Community Engine//EN'
        calendar.publish

        # Add timezone components for events with non-UTC timezones
        add_timezones_to_calendar(calendar)

        @events.each do |event|
          add_event_to_calendar(calendar, event)
        end

        Formatter.normalize_line_endings(calendar.to_ical)
      end

      private

      attr_reader :events

      def add_event_to_calendar(calendar, schedulable)
        calendar.event do |cal_event|
          EventBuilder.new(schedulable).build_icalendar_event(cal_event)
        end
      end

      def add_timezones_to_calendar(calendar)
        timezones = @events.map do |event|
          next unless event.respond_to?(:timezone) && event.timezone.present?
          next if ['UTC', 'Etc/UTC'].include?(event.timezone)

          event.timezone
        end.compact.uniq

        timezones.each do |tz_id|
          add_timezone_component(calendar, tz_id)
        end
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def add_timezone_component(calendar, tz_id)
        tz = TZInfo::Timezone.get(tz_id)
        calendar.timezone do |cal_tz|
          cal_tz.tzid = tz_id

          # Add STANDARD component
          standard_period = find_timezone_period(tz, :standard)
          if standard_period
            cal_tz.standard do |std|
              std.dtstart = Icalendar::Values::DateTime.new(standard_period[:dtstart])
              std.tzoffsetfrom = format_offset(standard_period[:offset_from])
              std.tzoffsetto = format_offset(standard_period[:offset_to])
            end
          end

          # Add DAYLIGHT component if timezone observes DST
          daylight_period = find_timezone_period(tz, :daylight)
          if daylight_period
            cal_tz.daylight do |dst|
              dst.dtstart = Icalendar::Values::DateTime.new(daylight_period[:dtstart])
              dst.tzoffsetfrom = format_offset(daylight_period[:offset_from])
              dst.tzoffsetto = format_offset(daylight_period[:offset_to])
            end
          end
        end
      rescue TZInfo::InvalidTimezoneIdentifier
        # Skip invalid timezones
        nil
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength
      def find_timezone_period(timezone, period_type) # rubocop:todo Metrics/AbcSize
        # For timezones with DST, find both standard and daylight periods
        # For timezones without DST, return only standard period
        transitions = timezone.transitions_up_to(Time.utc(2025, 12, 31), Time.utc(2024, 1, 1))

        if period_type == :daylight
          # Find a daylight (DST) period
          dst_transition = transitions.find { |t| t.offset.dst? }
          return nil unless dst_transition

          transition_time = Time.at(dst_transition.at.to_i).utc
          {
            dtstart: transition_time.strftime('%Y%m%dT%H%M%S'),
            offset_from: dst_transition.previous_offset.utc_total_offset,
            offset_to: dst_transition.offset.utc_total_offset
          }
        else
          # Find a standard (non-DST) period
          std_transition = transitions.find { |t| !t.offset.dst? }
          if std_transition
            transition_time = Time.at(std_transition.at.to_i).utc
            {
              dtstart: transition_time.strftime('%Y%m%dT%H%M%S'),
              offset_from: std_transition.previous_offset.utc_total_offset,
              offset_to: std_transition.offset.utc_total_offset
            }
          else
            # Timezone has no DST, use current period
            period = timezone.current_period
            {
              dtstart: Time.utc(2024, 3, 15).strftime('%Y%m%dT%H%M%S'),
              offset_from: period.utc_total_offset,
              offset_to: period.utc_total_offset
            }
          end
        end
      end
      # rubocop:enable Metrics/MethodLength

      def format_offset(seconds)
        hours = seconds / 3600
        minutes = (seconds % 3600) / 60
        sign = seconds >= 0 ? '+' : '-'
        format('%<sign>s%<hours>02d%<minutes>02d', sign: sign, hours: hours.abs, minutes: minutes.abs)
      end
    end
  end
end
