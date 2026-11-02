# frozen_string_literal: true

# Reads recorded Environment Canada responses from spec/fixtures/files/weather.
module WeatherFixtures
  def weather_fixture(name)
    BetterTogether::Engine.root.join('spec/fixtures/files/weather/environment_canada', name).read
  end

  def climate_properties(name)
    JSON.parse(weather_fixture(name)).fetch('features').pluck('properties')
  end
end

RSpec.configure { |config| config.include WeatherFixtures }
