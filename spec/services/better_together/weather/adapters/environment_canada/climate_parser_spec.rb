# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::Adapters::EnvironmentCanada::ClimateParser do
  describe '.hourly' do
    it 'keys rows on the UTC hour bucket and converts wind direction from tens of degrees' do
      rows = described_class.hourly(climate_properties('climate_hourly_st_johns.json'))

      expect(rows.size).to eq(6)
      expect(rows.first).to include(observed_at: Time.utc(2026, 11, 1, 4), condition: 'Rain')
      expect(rows.first[:values]).to include(temperature_c: 2.2, wind_speed_kmh: 44.0, wind_direction_deg: 340.0,
                                             visibility_km: 24.1, humidity_pct: 92.0, pressure_kpa: 98.82,
                                             precip_mm: nil)
    end

    it 'keeps absent Corner Brook measurements nil and drops the NA condition' do
      row = described_class.hourly(climate_properties('climate_hourly_corner_brook.json')).first

      expect(row[:condition]).to be_nil
      expect(row[:values]).to include(precip_mm: nil, visibility_km: nil, wind_chill: -5.0)
    end

    it 'skips rows without a usable UTC time' do
      expect(described_class.hourly([{ 'UTC_DATE' => nil, 'TEMP' => 1 }])).to eq([])
    end
  end

  describe '.daily' do
    subject(:rows) { described_class.daily(climate_properties('climate_daily_st_johns.json')) }

    it 'keys rows on the local date at 00:00 UTC' do
      expect(rows.map { |row| row[:observed_at] }).to eq([Time.utc(2026, 11, 1), Time.utc(2026, 10, 31),
                                                          Time.utc(2026, 10, 30)])
    end

    it 'maps daily measurements' do
      expect(rows[1][:values]).to include(temperature_c: 6.0, temperature_min_c: 1.1, temperature_max_c: 10.8,
                                          precip_mm: 27.6, wind_gust_kmh: 65.0)
    end

    it 'drops rows with no measurements' do
      empty = { 'LOCAL_DATE' => '2026-11-02 00:00:00', 'MEAN_TEMPERATURE' => nil, 'TOTAL_PRECIPITATION' => nil }
      expect(described_class.daily([empty])).to eq([])
    end
  end
end
