# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::Retention do
  let(:location) { create(:weather_location) }

  before do
    create(:weather_observation, location: location, observed_at: 500.days.ago.beginning_of_hour)
    create(:weather_observation, location: location, observed_at: 2.days.ago.beginning_of_hour)
    create(:weather_forecast, location: location, kind: 'hourly', issued_at: 10.days.ago, fetched_at: 10.days.ago)
    create(:weather_forecast, location: location, kind: 'daily', issued_at: 9.days.ago, fetched_at: 9.days.ago)
    create(:weather_forecast, location: location, kind: 'hourly', issued_at: 8.days.ago, fetched_at: 8.days.ago)
  end

  it 'deletes old observations and superseded forecasts but keeps the newest issue of each kind' do
    result = described_class.new.call

    expect(result[:observations]).to include(deleted_count: 1)
    expect(result[:forecasts]).to include(deleted_count: 1)
    expect(location.observations.count).to eq(1)
    expect(location.forecasts.pluck(:kind)).to contain_exactly('daily', 'hourly')
  end

  it 'keeps the most recently fetched issue even when an older one claims a later issue time' do
    stuck = create(:weather_forecast, location: location, kind: 'daily', issued_at: 1.day.from_now, fetched_at: 12.days.ago)

    described_class.new.call

    expect(BetterTogether::Weather::Forecast.exists?(stuck.id)).to be(false)
    expect(location.forecasts.daily.pluck(:fetched_at)).to all(be > 10.days.ago)
  end

  it 'reports without deleting on a dry run' do
    result = described_class.new(dry_run: true).call

    expect(result[:observations]).to include(eligible_count: 1, deleted_count: 0)
    expect(BetterTogether::Weather::Observation.count).to eq(2)
    expect(BetterTogether::Weather::Forecast.count).to eq(3)
  end
end
