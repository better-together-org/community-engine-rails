# frozen_string_literal: true

# Synthetic weather for feature and screenshot specs. Corner Brook style: no precipitation reading.
module WeatherPanelSeed
  def seed_weather_panel(location, now: Time.current)
    seed_current(location, now)
    seed_forecasts(location, now)
    seed_history(location, now)
  end

  private

  def seed_current(location, now)
    create(:weather_current_condition, location: location, observed_at: now, fetched_at: now,
                                       payload: { 'condition' => 'Mainly cloudy',
                                                  'values' => { 'temperature_c' => 3.0, 'humidity_pct' => 82,
                                                                'wind_speed_kmh' => 18, 'wind_gust_kmh' => 34,
                                                                'pressure_kpa' => 101.2, 'dew_point_c' => 0.4,
                                                                'visibility_km' => 24, 'wind_chill' => -2 },
                                                  'extras' => { 'wind_direction' => 'SW', 'sunrise' => '07:12',
                                                                'sunset' => '16:48' } })
  end

  def seed_forecasts(location, now)
    hours = (1..24).map do |h|
      { 'starts_at' => (now.beginning_of_hour + h.hours).iso8601, 'condition' => 'Cloudy',
        'temperature_c' => (3 + (Math.sin(h / 4.0) * 2)).round(1), 'pop_pct' => (h * 3) % 60, 'wind_speed_kmh' => 15 }
    end
    days = ['Tonight', 'Wednesday', 'Wednesday night', 'Thursday', 'Thursday night', 'Friday'].map do |name|
      { 'name' => name, 'summary' => 'Periods of rain. Wind southwest 30 km/h.', 'temperature_c' => 4,
        'temperature_class' => 'high', 'pop_pct' => 60 }
    end
    create(:weather_forecast, location: location, kind: 'hourly', payload: { 'periods' => hours })
    create(:weather_forecast, location: location, kind: 'daily', payload: { 'periods' => days })
  end

  def seed_history(location, now) # rubocop:disable Metrics/AbcSize
    (1..14).each do |d|
      (0..23).step(3) do |h|
        at = (now - d.days).beginning_of_day + h.hours
        create(:weather_observation, location: location, observed_at: at,
                                     temperature_c: (2 + (Math.sin(((d * 24) + h) / 9.0) * 4)).round(1),
                                     wind_speed_kmh: 12 + ((d * h) % 20), wind_gust_kmh: 25 + ((d * h) % 25))
      end
    end
  end
end

RSpec.configure { |config| config.include WeatherPanelSeed, :weather_seed }
