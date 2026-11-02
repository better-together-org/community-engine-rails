# frozen_string_literal: true

module BetterTogether
  module Weather
    # Per-day history for a location, read only from stored observations (never from
    # the source API). Days are the location's local calendar days, ending today.
    # Official daily rows win; hourly rows fill whatever a daily row lacks. Today is partial.
    class HistorySeries
      DEFAULT_DAYS = 14

      def initialize(location, days: DEFAULT_DAYS, now: Time.current)
        @location = location
        @day_count = days
        @now = now
        @zone = ActiveSupport::TimeZone[location.time_zone]
      end

      def today
        @today ||= @now.in_time_zone(@zone).to_date
      end

      # Oldest first: the previous `days` local days plus today so far.
      def days
        @days ||= ((today - @day_count)..today).map { |date| summarize(date) }
      end

      def reported?(measure)
        days.any? { |day| day.reported?(measure) }
      end

      def empty?
        days.all?(&:empty?)
      end

      private

      def summarize(date)
        hours = hourly_by_date[date] || []
        official = daily_by_date[date]
        DailySummary.new(date: date, partial: date == today, **temperatures(hours, official),
                         **precipitation(hours, official), **wind(hours, official))
      end

      def temperatures(hours, official)
        temps = hours.filter_map(&:temperature_c)
        {
          temperature_min_c: official&.temperature_min_c || temps.min,
          temperature_max_c: official&.temperature_max_c || temps.max,
          temperature_mean_c: official&.temperature_c || mean(temps)
        }
      end

      def precipitation(hours, official)
        {
          precip_mm: official&.precip_mm || total(hours.filter_map(&:precip_mm)),
          snow_cm: official&.snow_cm || total(hours.filter_map(&:snow_cm))
        }
      end

      def wind(hours, official)
        {
          wind_speed_kmh: official&.wind_speed_kmh || hours.filter_map(&:wind_speed_kmh).max,
          wind_gust_kmh: official&.wind_gust_kmh || hours.filter_map(&:wind_gust_kmh).max
        }
      end

      def mean(values)
        (values.sum / values.size).round(1) if values.any?
      end

      def total(values)
        values.sum.round(1) if values.any?
      end

      def hourly_by_date
        @hourly_by_date ||= @location.observations.hourly.between(window_start, @now)
                                     .group_by { |observation| observation.observed_at.in_time_zone(@zone).to_date }
      end

      # Daily rows are keyed by the local date at 00:00 UTC.
      def daily_by_date
        @daily_by_date ||= @location.observations.daily
                                    .between(utc_midnight(today - @day_count), utc_midnight(today))
                                    .index_by { |observation| observation.observed_at.utc.to_date }
      end

      def window_start
        (today - @day_count).in_time_zone(@zone).beginning_of_day
      end

      def utc_midnight(date)
        Time.utc(date.year, date.month, date.day)
      end
    end
  end
end
