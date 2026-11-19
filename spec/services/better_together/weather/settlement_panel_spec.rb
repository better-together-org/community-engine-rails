# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::SettlementPanel do
  subject(:panel) { described_class.new(location, now: now) }

  let(:location) { create(:weather_location) }
  let(:now) { Time.utc(2026, 11, 10, 15, 30) }

  def panel_key(time = now)
    described_class.new(location.reload, now: time).cache_key
  end

  def forecast(kind, periods)
    create(:weather_forecast, location: location, kind: kind, payload: { 'periods' => periods })
  end

  it 'has no data for a location with nothing stored' do
    expect(panel).not_to be_data
    expect(panel).to be_stale
  end

  it 'has data once a current condition is stored' do
    create(:weather_current_condition, location: location, observed_at: now - 5.minutes, fetched_at: now - 5.minutes,
                                       payload: { 'values' => { 'temperature_c' => 4.0 }, 'condition' => 'Cloudy' })

    expect(panel).to be_data
    expect(panel).not_to be_stale
    expect(panel.current_condition_text).to eq('Cloudy')
    expect(panel.current_values['temperature_c']).to eq(4.0)
  end

  it 'is stale when the current condition is old' do
    create(:weather_current_condition, location: location, observed_at: now - 1.day, fetched_at: now - 1.day)

    expect(panel).to be_stale
  end

  it 'drops hourly periods whose hour has finished and limits to 24' do
    periods = (-3..30).map { |h| { 'starts_at' => (now.beginning_of_hour + h.hours).iso8601, 'temperature_c' => h } }
    forecast('hourly', periods)

    expect(panel.hourly_periods.size).to eq(24)
    expect(panel.hourly_periods.first['temperature_c']).to eq(0)
  end

  it 'limits daily periods to 13' do
    forecast('daily', Array.new(15) { |i| { 'name' => "P#{i}" } })

    expect(panel.daily_periods.size).to eq(13)
  end

  it 'reports a source error from the location' do
    location.update!(last_error_at: now, last_error: 'timeout')

    expect(panel).to be_source_error
  end

  it 'exposes the adapter attribution and licence link' do
    expect(panel.attribution).to include('Environment and Climate Change Canada')
    expect(panel.licence_url).to start_with('https://')
  end

  it 'shows the forecast issue fetched most recently even when an older document claims a later issue' do
    create(:weather_forecast, location: location, kind: 'hourly', issued_at: now + 4.hours, fetched_at: now - 7.hours,
                              payload: { 'periods' => [{ 'starts_at' => (now + 1.hour).iso8601, 'temperature_c' => -9 }] })
    create(:weather_forecast, location: location, kind: 'hourly', issued_at: now - 1.hour, fetched_at: now - 5.minutes,
                              payload: { 'periods' => [{ 'starts_at' => (now + 1.hour).iso8601, 'temperature_c' => 2 }] })

    expect(panel.hourly_periods.map { |period| period['temperature_c'] }).to eq([2])
  end

  describe 'freshness' do
    before do
      create(:weather_current_condition, location: location, observed_at: now - 5.hours, fetched_at: now - 4.hours)
    end

    it 'reports the observation time, not the fetch time, as the last update' do
      expect(panel.last_updated).to eq(now - 5.hours)
    end

    it 'says the station is silent when the source answered after the last observation' do
      location.update!(last_refreshed_at: now - 10.minutes)

      expect(panel).to be_source_silent
      expect(panel.last_checked).to eq(now - 10.minutes)
    end

    it 'is not silent when the source has not been reached since' do
      location.update!(last_refreshed_at: now - 6.hours)

      expect(panel).not_to be_source_silent
    end
  end

  describe '#cache_key' do
    before do
      create(:weather_current_condition, location: location, observed_at: now, fetched_at: now)
      create(:weather_observation, location: location, observed_at: now - 2.hours)
    end

    it 'is stable while nothing changes' do
      first = panel_key

      expect(panel_key).to eq(first)
    end

    it 'changes when a new observation arrives' do
      expect { create(:weather_observation, location: location, observed_at: now - 1.hour) }.to(change { panel_key })
    end

    it 'changes when an observation is updated, a forecast arrives or conditions change' do
      expect { location.observations.first.update!(temperature_c: 42) }.to(change { panel_key })
      expect { create(:weather_forecast, location: location) }.to(change { panel_key })
      expect { location.current_condition.update!(observed_at: now + 1.minute) }.to(change { panel_key })
    end

    it 'changes with the hour, the locale and a refresh' do
      expect(panel_key(now + 1.hour)).not_to eq(panel_key)
      expect(I18n.with_locale(:fr) { panel_key }).not_to eq(panel_key)
      expect { location.update!(last_refreshed_at: now) }.to(change { panel_key })
    end
  end
end
