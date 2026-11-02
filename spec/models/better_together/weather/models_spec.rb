# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Weather models' do # rubocop:disable RSpec/DescribeClass
  describe BetterTogether::Weather::Source do
    it 'is valid with a registered adapter' do
      expect(build(:weather_source)).to be_valid
    end

    it 'rejects an unregistered adapter and a duplicate identifier' do
      create(:weather_source, identifier: 'eccc')

      expect(build(:weather_source, adapter_key: 'nope')).not_to be_valid
      expect(build(:weather_source, identifier: 'eccc')).not_to be_valid
    end

    it 'builds its adapter from the registry' do
      expect(build(:weather_source).adapter).to be_a(BetterTogether::Weather::Adapters::EnvironmentCanada)
    end
  end

  describe BetterTogether::Weather::Location do
    subject(:location) { create(:weather_location) }

    it 'is unique per settlement and source' do
      duplicate = build(:weather_location, settlement: location.settlement, source: location.source)
      expect(duplicate).not_to be_valid
    end

    it 'validates the time zone as an IANA identifier' do
      expect(build(:weather_location, time_zone: 'Eastern Time (US & Canada)')).not_to be_valid
    end

    it 'prefers its own coordinates and falls back to the settlement' do
      location.update!(latitude: 48.95, longitude: -57.95)
      expect([location.latitude, location.longitude]).to eq([48.95, -57.95])

      allow(location.settlement).to receive_messages(latitude: 1.5, longitude: 2.5)
      location.update!(latitude: nil, longitude: nil)
      expect([location.latitude, location.longitude]).to eq([1.5, 2.5])
    end

    it 'enqueues the first refresh and backfill when created' do
      expect { create(:weather_location) }
        .to have_enqueued_job(BetterTogether::Weather::RefreshLocationJob)
        .and have_enqueued_job(BetterTogether::Weather::BackfillLocationJob)
    end

    it 'records and clears errors' do
      location.record_error!(StandardError.new('boom'))
      expect(location.last_error).to eq('StandardError: boom')

      location.record_success!(last_current_fetched_at: Time.current)
      expect(location.reload).to have_attributes(last_error: nil, last_error_at: nil)
    end
  end

  describe BetterTogether::Weather::Observation do
    it 'enforces one reading per location, granularity and time' do
      existing = create(:weather_observation)
      duplicate = build(:weather_observation, location: existing.location, observed_at: existing.observed_at)

      expect(duplicate).not_to be_valid
    end

    it 'validates granularity and origin' do
      expect(build(:weather_observation, granularity: 'weekly')).not_to be_valid
      expect(build(:weather_observation, origin: 'guess')).not_to be_valid
    end

    it 'fills only nil measurements' do
      observation = build(:weather_observation, temperature_c: 3.0, precip_mm: nil)
      filled = observation.fill_missing_from(temperature_c: 9.0, precip_mm: 1.0)

      expect(filled).to eq([:precip_mm])
      expect(observation).to have_attributes(temperature_c: 3.0, precip_mm: 1.0)
    end
  end

  describe BetterTogether::Weather::CurrentCondition do
    it 'is stale after three hours' do
      condition = build(:weather_current_condition, observed_at: 4.hours.ago, fetched_at: 1.minute.ago)
      expect(condition).to be_stale
      expect(build(:weather_current_condition, observed_at: 1.hour.ago)).not_to be_stale
    end
  end

  describe BetterTogether::Weather::Forecast do
    it 'validates kind and exposes periods' do
      forecast = build(:weather_forecast, payload: { 'periods' => [{ 'a' => 1 }] })

      expect(forecast.periods).to eq([{ 'a' => 1 }])
      expect(build(:weather_forecast, kind: 'monthly')).not_to be_valid
    end
  end
end
