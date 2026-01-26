# frozen_string_literal: true

module BetterTogether
  module Ics
    # Builds VTIMEZONE components for ICS calendar export
    # Handles timezone information including DST transitions
    class TimezoneBuilder
      def initialize(timezone, reference_time)
        @timezone = timezone
        @reference_time = reference_time
      end

      # Generate VTIMEZONE component lines
      # Returns empty array if timezone is UTC or not present
      def build
        return [] unless timezone_present? && !uses_utc?

        tz = ActiveSupport::TimeZone[timezone]
        return [] unless tz

        tzinfo = tz.tzinfo
        period = tzinfo.period_for_utc(reference_time.utc)

        lines = [
          'BEGIN:VTIMEZONE',
          "TZID:#{timezone}"
        ]

        lines.concat(standard_time_component(tzinfo, period))
        lines.concat(daylight_time_component(tzinfo, period)) if recent_dst?(tzinfo)

        lines << 'END:VTIMEZONE'
        lines
      end

      private

      attr_reader :timezone, :reference_time

      def timezone_present?
        timezone.present?
      end

      def uses_utc?
        ['UTC', 'Etc/UTC'].include?(timezone)
      end

      # Check if timezone has DST transitions in a modern window around the reference time
      # Ignores historic anomalies by only looking at transitions within 10 years
      def recent_dst?(tzinfo)
        window_start = reference_time.utc - 10.years
        window_end = reference_time.utc + 10.years

        tzinfo.transitions_up_to(window_end, window_start).any? do |transition|
          dst_offset?(transition)
        end
      end

      def dst_offset?(transition)
        (transition.offset&.std_offset && transition.offset.std_offset != 0) ||
          (transition.previous_offset && transition.previous_offset.std_offset != 0)
      end

      # Generate STANDARD time component for non-DST periods
      def standard_time_component(tzinfo, period) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        offset = period.offset
        base_offset = offset.base_utc_offset

        # Find most recent standard time transition (if any)
        transitions = tzinfo.transitions_up_to(reference_time.utc)

        # Prefer the previous offset from a recent transition when it represents a genuine
        # recent offset change (e.g., DST <-> STANDARD). Otherwise, fall back to the
        # current period's observed offset so non-DST zones don't pick up historic anomalies.
        transition = transitions.reverse.find do |t|
          # consider transitions within a 10 year window of the event
          transition_time = Time.at(t.timestamp_value)
          (reference_time.utc - transition_time).abs <= 10.years
        end

        if transition&.previous_offset
          prev_seconds = transition.previous_offset.observed_utc_offset
          # If the previous offset is meaningfully different, use it; otherwise fall back
          from_offset = if prev_seconds == period.offset.observed_utc_offset
                          Formatter.utc_offset(period.offset.observed_utc_offset)
                        else
                          Formatter.utc_offset(prev_seconds)
                        end
        else
          from_offset = Formatter.utc_offset(period.offset.observed_utc_offset)
        end

        [
          'BEGIN:STANDARD',
          "DTSTART:#{reference_time.strftime('%Y%m%dT%H%M%S')}",
          "TZOFFSETFROM:#{from_offset}",
          "TZOFFSETTO:#{Formatter.utc_offset(base_offset)}",
          'END:STANDARD'
        ]
      end

      # Generate DAYLIGHT time component for DST periods
      def daylight_time_component(_tzinfo, period)
        offset = period.offset
        utc_offset = offset.observed_utc_offset
        base_offset = offset.base_utc_offset

        # No daylight component if offsets are the same
        return [] if utc_offset == base_offset

        from_offset = Formatter.utc_offset(base_offset)
        to_offset = Formatter.utc_offset(utc_offset)

        [
          'BEGIN:DAYLIGHT',
          "DTSTART:#{reference_time.strftime('%Y%m%dT%H%M%S')}",
          "TZOFFSETFROM:#{from_offset}",
          "TZOFFSETTO:#{to_offset}",
          'END:DAYLIGHT'
        ]
      end
    end
  end
end
