# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::RefreshLocation do
  let(:location) { create(:weather_location) }
  let(:now) { Time.utc(2026, 11, 2, 17, 20) }
  let(:parsed) { BetterTogether::Weather::Adapters::EnvironmentCanada::CitypageParser.parse(weather_fixture('citypage_corner_brook_en.xml')) }
  let(:snapshot) { { current: parsed[:current], forecasts: parsed[:forecasts] } }
  let(:adapter) { instance_double(BetterTogether::Weather::Adapters::EnvironmentCanada, fetch_snapshot: snapshot) }

  before { allow(location.source).to receive(:adapter).and_return(adapter) }

  def refresh
    allow(location).to receive(:adapter).and_return(adapter)
    described_class.call(location, now: now)
  end

  it 'stores current conditions, both forecasts and one live observation' do
    refresh

    expect(location.current_condition.payload['values']).to include('temperature_c' => 6.0)
    expect(location.forecasts.pluck(:kind)).to contain_exactly('hourly', 'daily')
    expect(location.observations.hourly.pluck(:observed_at)).to eq([Time.utc(2026, 11, 2, 17)])
    expect(location.observations.first).to have_attributes(origin: 'live_feed', temperature_c: 6.0, precip_mm: nil)
    expect(location.reload).to have_attributes(last_current_fetched_at: now, last_error: nil)
  end

  it 'is idempotent across repeated refreshes of the same document' do
    2.times { refresh }

    expect(location.observations.count).to eq(1)
    expect(location.forecasts.count).to eq(2)
    expect(BetterTogether::Weather::CurrentCondition.where(location: location).count).to eq(1)
  end

  it 'does not replace an official backfilled row with the live feed' do
    create(:weather_observation, location: location, observed_at: Time.utc(2026, 11, 2, 17), origin: 'backfill_api',
                                 temperature_c: 5.5)
    refresh

    expect(location.observations.sole).to have_attributes(origin: 'backfill_api', temperature_c: 5.5)
  end

  it 'keeps values a backfill already filled in when the live feed has none for that field' do
    create(:weather_observation, location: location, observed_at: Time.utc(2026, 11, 2, 17), origin: 'live_feed',
                                 temperature_c: 1.0, precip_mm: 0.4)
    refresh

    expect(location.observations.sole).to have_attributes(temperature_c: 6.0, precip_mm: 0.4)
  end

  it 'records the error and keeps stored data when the source fails' do
    refresh
    allow(adapter).to receive(:fetch_snapshot).and_raise(BetterTogether::Weather::Http::Error, 'down')

    expect(described_class.call(location, now: now + 1.hour)).to be_nil
    expect(location.reload.last_error).to include('down')
    expect(location.observations.count).to eq(1)
    expect(location.current_condition).to be_present
  end

  it 'lets unexpected errors propagate so the job can retry' do
    allow(adapter).to receive(:fetch_snapshot).and_raise(NoMethodError, 'bug')
    allow(location).to receive(:adapter).and_return(adapter)

    expect { described_class.call(location, now: now) }.to raise_error(NoMethodError)
  end
end
