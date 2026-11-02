# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::HistorySeries do
  subject(:series) { described_class.new(location, now: now) }

  let(:location) { create(:weather_location, time_zone: 'America/St_Johns') }
  # 12:00 local on Nov 10 (NST is UTC-3:30)
  let(:now) { Time.utc(2026, 11, 10, 15, 30) }

  def hourly(at, **attrs)
    create(:weather_observation, location: location, granularity: 'hourly', observed_at: at, **attrs)
  end

  def daily(date, **attrs)
    create(:weather_observation, location: location, granularity: 'daily',
                                 observed_at: Time.utc(date.year, date.month, date.day), **attrs)
  end

  it 'covers the previous 14 local days plus today, oldest first' do
    expect(series.days.map(&:date)).to eq(((Date.new(2026, 11, 10) - 14)..Date.new(2026, 11, 10)).to_a)
  end

  it 'marks only today as partial' do
    expect(series.days.select(&:partial?).map(&:date)).to eq([Date.new(2026, 11, 10)])
  end

  it 'is empty without observations' do
    expect(series).to be_empty
  end

  it 'prefers the official daily row over hourly aggregates' do
    day = Date.new(2026, 11, 5)
    daily(day, temperature_min_c: -2.0, temperature_max_c: 6.0, temperature_c: 2.0)
    hourly(Time.utc(2026, 11, 5, 15), temperature_c: 20.0)

    summary = series.days.find { |d| d.date == day }
    expect([summary.temperature_min_c, summary.temperature_max_c, summary.temperature_mean_c]).to eq([-2.0, 6.0, 2.0])
  end

  it 'falls back to hourly aggregates when no daily row exists' do
    day = Date.new(2026, 11, 6)
    hourly(Time.utc(2026, 11, 6, 15), temperature_c: 2.0, precip_mm: 1.2, wind_speed_kmh: 10, wind_gust_kmh: 30)
    hourly(Time.utc(2026, 11, 6, 16), temperature_c: 6.0, precip_mm: 0.8, wind_speed_kmh: 25, wind_gust_kmh: 40)

    summary = series.days.find { |d| d.date == day }
    expect(summary).to have_attributes(temperature_min_c: 2.0, temperature_max_c: 6.0, temperature_mean_c: 4.0,
                                       precip_mm: 2.0, wind_speed_kmh: 25, wind_gust_kmh: 40)
  end

  it 'keeps unreported measurements nil rather than zero' do
    hourly(Time.utc(2026, 11, 6, 15), temperature_c: 2.0)

    summary = series.days.find { |d| d.date == Date.new(2026, 11, 6) }
    expect(summary.precip_mm).to be_nil
    expect(series.reported?(:precip_mm)).to be false
    expect(series.reported?(:temperature_max_c)).to be true
  end

  it 'buckets hourly rows by the local date, not the UTC date' do
    # 01:00 UTC on Nov 7 is 21:30 local on Nov 6
    hourly(Time.utc(2026, 11, 7, 1), temperature_c: 3.0)

    expect(series.days.find { |d| d.date == Date.new(2026, 11, 6) }.temperature_max_c).to eq(3.0)
    expect(series.days.find { |d| d.date == Date.new(2026, 11, 7) }.temperature_max_c).to be_nil
  end

  it 'never calls the source' do
    allow(SsrfFilter).to receive(:get).and_raise('network used')
    hourly(Time.utc(2026, 11, 6, 15), temperature_c: 2.0)

    expect { series.days }.not_to raise_error
  end
end
