# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::SettlementPanel do
  subject(:panel) { described_class.new(location, now: now) }

  let(:location) { create(:weather_location) }
  let(:now) { Time.utc(2026, 11, 10, 15, 30) }

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
end
