# frozen_string_literal: true

module BetterTogether
  module Ics
    # Utility methods for formatting times and offsets in ICS format
    class Formatter
      class << self
        # Format current time as ICS timestamp (YYYYMMDDTHHMMSSZ in UTC)
        def timestamp
          Time.current.utc.strftime('%Y%m%dT%H%M%SZ')
        end

        # Format a datetime in UTC for ICS (YYYYMMDDTHHMMSSZ)
        def utc_time(datetime)
          return nil unless datetime

          datetime.utc.strftime('%Y%m%dT%H%M%SZ')
        end

        # Format a datetime in local timezone for ICS (YYYYMMDDTHHMMSS without Z)
        def local_time(datetime, timezone)
          return nil unless datetime && timezone

          tz = ActiveSupport::TimeZone[timezone]
          return nil unless tz

          local_datetime = datetime.in_time_zone(tz)
          local_datetime.strftime('%Y%m%dT%H%M%S')
        end

        # Format UTC offset in ICS format (+HHMM or -HHMM)
        def utc_offset(seconds)
          hours = seconds / 3600
          minutes = (seconds.abs % 3600) / 60
          sign = seconds.negative? ? '-' : '+'
          format('%<sign>s%<hours>02d%<minutes>02d', sign: sign, hours: hours.abs, minutes: minutes)
        end

        # Ensure proper ICS line endings (\r\n)
        def normalize_line_endings(content)
          content.gsub(/(?<!\r)\n/, "\r\n")
        end
      end
    end
  end
end
