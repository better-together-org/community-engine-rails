# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::Adapters::EnvironmentCanada::CitypageParser do
  subject(:parsed) { described_class.parse(weather_fixture('citypage_corner_brook_en.xml')) }

  let(:daily) { parsed[:forecasts].find { |forecast| forecast[:kind] == 'daily' } }
  let(:hourly) { parsed[:forecasts].find { |forecast| forecast[:kind] == 'hourly' } }

  it 'reads the document creation time in UTC' do
    expect(parsed[:created_at]).to eq(Time.utc(2026, 11, 2, 17, 1, 53))
  end

  describe 'current conditions' do
    subject(:current) { parsed[:current] }

    it 'reads the observation time and station' do
      expect(current).to include(observed_at: Time.utc(2026, 11, 2, 17, 0, 0), station_ref: 'wkb')
    end

    it 'reads the measurements as floats' do
      expect(current[:values]).to include(temperature_c: 6.0, dew_point_c: -0.2, pressure_kpa: 100.9,
                                          humidity_pct: 64.0, wind_speed_kmh: 17.0, wind_gust_kmh: 29.0,
                                          wind_direction_deg: 283.9)
    end

    it 'returns nil, not zero, for measurements the station does not report' do
      expect(current[:values]).to include(visibility_km: nil, humidex: nil, wind_chill: nil)
    end

    it 'treats the empty condition of an automatic station as nil' do
      expect(current[:condition]).to be_nil
    end

    it 'keeps wind direction text, pressure tendency and sun times as extras' do
      expect(current[:extras]).to include(wind_direction: 'WNW', pressure_tendency: 'rising')
      expect(current[:extras][:sunrise]).to match(/\A2026-11-02T10:40:00/)
    end
  end

  describe 'daily forecast' do
    it 'has the 13 half-day periods and the issue time' do
      expect(daily[:periods].size).to eq(13)
      expect(daily[:issued_at]).to eq(Time.utc(2026, 11, 2, 14, 30, 0))
    end

    it 'reads the first period' do
      expect(daily[:periods].first).to include(name: 'Today', temperature_c: 8.0, temperature_class: 'high',
                                               pop_pct: 40.0, wind_speed_kmh: 30.0, wind_gust_kmh: 50.0,
                                               wind_direction: 'NW', icon_code: '06')
    end
  end

  describe 'hourly forecast' do
    it 'has 24 hourly periods in UTC' do
      expect(hourly[:periods].size).to eq(24)
      expect(hourly[:periods].first).to include(starts_at: '2026-11-02T18:00:00Z', temperature_c: 6.0,
                                                pop_pct: 0.0, wind_speed_kmh: 30.0, wind_gust_kmh: 50.0)
    end
  end

  it 'returns no current conditions when the observation block is missing' do
    xml = '<siteData><dateTime name="xmlCreation" zone="UTC"><timeStamp>20261102170153</timeStamp></dateTime></siteData>'
    expect(described_class.parse(xml)).to include(current: nil, forecasts: [])
  end

  it 'raises on malformed XML instead of returning partial data' do
    expect { described_class.parse('<siteData><oops>') }.to raise_error(Nokogiri::XML::SyntaxError)
  end
end
