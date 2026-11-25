# frozen_string_literal: true

# last_refreshed_at records the last successful contact with the weather source, even
# when the source document carried no current conditions. The forecast index serves the
# panel query that picks the most recently fetched issue of each kind.
class AddLastRefreshedAtToBetterTogetherWeatherLocations < ActiveRecord::Migration[7.2]
  LOCATIONS = :better_together_weather_locations
  FORECASTS = :better_together_weather_forecasts
  FORECAST_INDEX = 'bt_weather_forecast_latest_fetch'

  def up
    add_column LOCATIONS, :last_refreshed_at, :datetime if table_exists?(LOCATIONS) && !column_exists?(LOCATIONS, :last_refreshed_at)
    return unless table_exists?(FORECASTS)
    return if index_name_exists?(FORECASTS, FORECAST_INDEX)

    add_index FORECASTS, %i[location_id kind fetched_at], name: FORECAST_INDEX
  end

  def down
    remove_index FORECASTS, name: FORECAST_INDEX if table_exists?(FORECASTS) && index_name_exists?(FORECASTS, FORECAST_INDEX)
    remove_column LOCATIONS, :last_refreshed_at if table_exists?(LOCATIONS) && column_exists?(LOCATIONS, :last_refreshed_at)
  end
end
