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

      # When the source last reported conditions (observation time, not our fetch time).
      def last_updated
        current&.observed_at || current&.fetched_at
      end

      # When the source was last reached, whether or not it reported new conditions.
      def last_checked
        location.last_refreshed_at
      end

      # The source answered after the stored conditions were observed, so the gap is the
      # station's, not a failing refresh.
      def source_silent?
        stale? && last_checked.present? && last_updated.present? && last_checked > last_updated
      end

      # Fragment cache key that follows the data: any new or changed reading, a refresh,
      # the clock hour (hourly cut-off and today), staleness, locale and zone.
      def cache_key
        ['better_together/weather/panel', *record_stamps, rows_stamp(location.forecasts),
         rows_stamp(location.observations), now.utc.beginning_of_hour.to_i, stale?, I18n.locale,
         location.time_zone].join('/')
      end

      def summary_cache_key
        ['better_together/weather/summary', *record_stamps, stale?, I18n.locale, location.time_zone].join('/')
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
        location.forecasts.where(kind: kind).most_recently_fetched.first&.periods || []
      end

      def record_stamps
        [location.id, stamp(location.updated_at), stamp(current&.updated_at)]
      end

      def stamp(time)
        time&.utc&.to_fs(:usec)
      end

      def rows_stamp(relation)
        table = relation.arel_table
        latest, count = relation.unscope(:order).pick(table[:updated_at].maximum, table[:id].count)
        "#{count}-#{stamp(latest)}"
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
