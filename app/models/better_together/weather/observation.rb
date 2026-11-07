# frozen_string_literal: true

module BetterTogether
  module Weather
    # One stored reading. Hourly rows are keyed by the top-of-hour UTC bucket;
    # daily rows by the local calendar date at 00:00 UTC. Measurements may be nil
    # when a station does not report them.
    class Observation < ApplicationRecord
      GRANULARITIES = %w[hourly daily].freeze
      ORIGINS = %w[live_feed backfill_api].freeze
      MEASUREMENTS = %i[
        temperature_c temperature_min_c temperature_max_c dew_point_c humidex wind_chill
        humidity_pct pressure_kpa wind_speed_kmh wind_gust_kmh wind_direction_deg
        visibility_km precip_mm snow_cm
      ].freeze

      belongs_to :location, class_name: 'BetterTogether::Weather::Location', inverse_of: :observations

      validates :granularity, inclusion: { in: GRANULARITIES }
      validates :origin, inclusion: { in: ORIGINS }
      validates :observed_at, presence: true
      validates :observed_at, uniqueness: { scope: %i[location_id granularity] }

      scope :hourly, -> { where(granularity: 'hourly') }
      scope :daily, -> { where(granularity: 'daily') }
      scope :between, ->(from, to) { where(observed_at: from..to) }
      scope :chronological, -> { order(:observed_at) }

      # Fills only the measurements that are currently nil; returns the filled names.
      def fill_missing_from(values)
        filled = MEASUREMENTS.select { |name| self[name].nil? && !values[name].nil? }
        filled.each { |name| self[name] = values[name] }
        self.condition ||= values[:condition]
        filled
      end
    end
  end
end
