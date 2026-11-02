# frozen_string_literal: true

# Stored weather readings per location: the latest current conditions, forecasts
# and the observation history that settlement pages and charts read from.
class CreateBetterTogetherWeatherReadings < ActiveRecord::Migration[7.1]
  MEASUREMENTS = %i[
    temperature_c temperature_min_c temperature_max_c dew_point_c humidex wind_chill
    humidity_pct pressure_kpa wind_speed_kmh wind_gust_kmh wind_direction_deg
    visibility_km precip_mm snow_cm
  ].freeze

  def change
    create_current_conditions
    create_forecasts
    create_observations
  end

  private

  def create_current_conditions
    return if table_exists?(:better_together_weather_current_conditions)

    create_bt_table :current_conditions, prefix: :better_together_weather do |t|
      t.bt_references :location, table_prefix: 'better_together_weather',
                                 index: { name: 'bt_weather_current_by_location', unique: true }
      t.datetime :observed_at
      t.datetime :fetched_at, null: false
      t.jsonb :payload, null: false, default: {}
    end
  end

  def create_forecasts
    return if table_exists?(:better_together_weather_forecasts)

    create_bt_table :forecasts, prefix: :better_together_weather do |t|
      t.bt_references :location, table_prefix: 'better_together_weather',
                                 index: { name: 'bt_weather_forecast_by_location' }
      t.string :kind, null: false, limit: 20
      t.datetime :issued_at, null: false
      t.datetime :fetched_at, null: false
      t.jsonb :payload, null: false, default: {}

      t.index %i[location_id kind issued_at], unique: true, name: 'bt_weather_forecast_unique_issue'
    end
  end

  def create_observations
    return if table_exists?(:better_together_weather_observations)

    create_bt_table :observations, prefix: :better_together_weather do |t|
      t.bt_references :location, table_prefix: 'better_together_weather',
                                 index: { name: 'bt_weather_observation_by_location' }
      t.string :granularity, null: false, limit: 10
      # Hourly: top-of-hour UTC bucket. Daily: the local calendar date at 00:00 UTC.
      t.datetime :observed_at, null: false
      t.string :origin, null: false, limit: 20
      MEASUREMENTS.each { |measurement| t.float measurement }
      t.string :condition
      t.jsonb :source_flags, null: false, default: {}

      t.index %i[location_id granularity observed_at], unique: true, name: 'bt_weather_observation_unique_reading'
    end
  end
end
