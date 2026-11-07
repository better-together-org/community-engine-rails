# frozen_string_literal: true

module BetterTogether
  module Weather
    # Everything the settlement weather panel shows, read from stored rows only.
    # It never calls the source: a failing or slow source cannot slow or break the page.
    class SettlementPanel
      HOURLY_LIMIT = 24
      DAILY_LIMIT = 13

      attr_reader :location, :now

      def initialize(location, now: Time.current)
        @location = location
        @now = now
      end

      def current
        @current ||= location.current_condition
      end

      def current_values
        (current&.payload || {}).fetch('values', {})
      end

      def current_extras
        (current&.payload || {}).fetch('extras', {})
      end

      def current_condition_text
        current&.payload&.dig('condition')
      end

      def hourly_periods
        @hourly_periods ||= upcoming(forecast_periods('hourly')).first(HOURLY_LIMIT)
      end

      def daily_periods
        @daily_periods ||= forecast_periods('daily').first(DAILY_LIMIT)
      end

      def history
        @history ||= HistorySeries.new(location, now: now)
      end

      def time_zone
        ActiveSupport::TimeZone[location.time_zone]
      end

      def data?
        current.present? || hourly_periods.any? || daily_periods.any? || !history.empty?
      end

      def stale?
        current.nil? || current.stale?(now: now)
      end

      def last_updated
        current&.fetched_at
      end

      def source_error?
        location.last_error_at.present?
      end

      def attribution
        location.adapter.attribution
      end

      def licence_url
        location.adapter.licence_url
      end

      private

      def forecast_periods(kind)
        location.forecasts.where(kind: kind).latest_first.first&.periods || []
      end

      # Hourly forecast periods whose hour has not finished yet.
      def upcoming(periods)
        cutoff = now.beginning_of_hour
        periods.select { |period| (starts_at(period) || cutoff) >= cutoff }
      end

      def starts_at(period)
        Time.iso8601(period['starts_at'].to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
