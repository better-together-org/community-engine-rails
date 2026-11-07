# frozen_string_literal: true

# Weather data sources (one per adapter configuration) and the settlement
# locations that are tracked through them.
class CreateBetterTogetherWeatherSourcesAndLocations < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:better_together_weather_sources)
      create_bt_table :sources, prefix: :better_together_weather do |t|
        t.bt_identifier
        t.string :adapter_key, null: false
        t.jsonb :config, null: false, default: {}
        t.boolean :enabled, null: false, default: true
      end
    end

    return if table_exists?(:better_together_weather_locations)

    create_bt_table :locations, prefix: :better_together_weather do |t|
      t.bt_references :settlement, target_table: :better_together_geography_settlements,
                                   index: { name: 'bt_weather_location_by_settlement' }
      t.bt_references :source, table_prefix: 'better_together_weather',
                               index: { name: 'bt_weather_location_by_source' }
      t.string :external_ref, null: false
      t.string :observation_station_ref
      t.string :precip_station_ref
      t.float :latitude
      t.float :longitude
      t.string :time_zone, null: false, default: 'UTC'
      t.boolean :enabled, null: false, default: true
      t.datetime :last_current_fetched_at
      t.datetime :last_forecast_fetched_at
      t.datetime :last_observations_backfilled_at
      t.datetime :last_error_at
      t.text :last_error

      t.index %i[settlement_id source_id], unique: true, name: 'bt_weather_location_unique_settlement_source'
    end
  end
end
