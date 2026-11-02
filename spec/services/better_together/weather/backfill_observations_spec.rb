# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::BackfillObservations do
  let(:location) { create(:weather_location, observation_station_ref: '8403505') }
  let(:now) { Time.utc(2026, 11, 2, 12, 30) }
  let(:parser) { BetterTogether::Weather::Adapters::EnvironmentCanada::ClimateParser }
  let(:hourly_rows) { parser.hourly(climate_properties('climate_hourly_st_johns.json')) }
  let(:daily_rows) { parser.daily(climate_properties('climate_daily_st_johns.json')) }
  let(:adapter) { instance_double(BetterTogether::Weather::Adapters::EnvironmentCanada, supports?: true) }

  before do
    allow(adapter).to receive(:fetch_observations) do |_loc, granularity:, **|
      granularity == 'daily' ? daily_rows : hourly_rows
    end
    allow(location).to receive(:adapter).and_return(adapter)
  end

  it 'creates missing hourly and daily rows tagged backfill_api' do
    stats = described_class.call(location, now: now)

    expect(stats).to include(created: 9)
    expect(location.observations.hourly.count).to eq(6)
    expect(location.observations.daily.count).to eq(3)
    expect(location.observations.pluck(:origin).uniq).to eq(['backfill_api'])
    expect(location.reload.last_observations_backfilled_at).to eq(now)
  end

  it 'is idempotent' do
    described_class.call(location, now: now)
    stats = described_class.call(location, now: now)

    expect(stats).to be_empty
    expect(location.observations.count).to eq(9)
  end

  it 'fills only missing measurements on live_feed rows and never overwrites live values' do
    live = create(:weather_observation, location: location, observed_at: Time.utc(2026, 11, 1, 4),
                                        origin: 'live_feed', temperature_c: 9.9, visibility_km: nil)
    described_class.call(location, now: now)

    expect(live.reload).to have_attributes(origin: 'live_feed', temperature_c: 9.9, visibility_km: 24.1)
    expect(live.source_flags['enriched']).to include('visibility_km')
  end

  it 'applies source corrections to rows it created itself' do
    described_class.call(location, now: now)
    row = location.observations.hourly.find_by(observed_at: Time.utc(2026, 11, 1, 4))
    row.update!(temperature_c: 0.0)

    expect(described_class.call(location, now: now)).to include(updated: 1)
    expect(row.reload.temperature_c).to eq(2.2)
  end

  it 'fills precipitation from a secondary station without creating rows from it' do
    location.update!(precip_station_ref: '8403603')
    secondary = hourly_rows.map { |row| row.merge(values: row[:values].merge(precip_mm: 1.2)) }
    allow(adapter).to receive(:fetch_observations).with(location, hash_including(station_ref: '8403603'))
                                                  .and_return(secondary + [{ observed_at: Time.utc(2025, 1, 1), values: { precip_mm: 3.0 },
                                                                             flags: {} }])

    described_class.call(location, now: now)

    expect(location.observations.hourly.pluck(:precip_mm).uniq).to eq([1.2])
    expect(location.observations.hourly.count).to eq(6)
  end

  it 'does nothing for a location without a station' do
    location.update!(observation_station_ref: nil)
    expect(described_class.call(location, now: now)).to be_nil
    expect(adapter).not_to have_received(:fetch_observations)
  end

  it 'records the error and keeps stored rows when the API fails' do
    described_class.call(location, now: now)
    allow(adapter).to receive(:fetch_observations).and_raise(BetterTogether::Weather::Http::Error, 'api down')

    expect(described_class.call(location, now: now)).to be_nil
    expect(location.reload.last_error).to include('api down')
    expect(location.observations.count).to eq(9)
  end
end
