# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::Adapters::EnvironmentCanada::ClimateClient do
  subject(:client) { described_class.new(http: http) }

  let(:http) { instance_double(BetterTogether::Weather::Http) }
  let(:from) { Time.utc(2026, 10, 19) }
  let(:to) { Time.utc(2026, 11, 2) }

  def page(count)
    { features: Array.new(count) { |i| { properties: { 'TEMP' => i } } } }.to_json
  end

  it 'requests the hourly collection with a padded window and returns the properties' do
    allow(http).to receive(:get).and_return(weather_fixture('climate_hourly_st_johns.json'))

    rows = client.fetch(granularity: 'hourly', climate_id: '8403505', from: from, to: to)

    expect(rows.size).to eq(6)
    expect(http).to have_received(:get).with(
      'https://api.weather.gc.ca/collections/climate-hourly/items',
      params: hash_including(CLIMATE_IDENTIFIER: '8403505', datetime: '2026-10-18T12:00:00Z/2026-11-02T12:00:00Z',
                             offset: 0)
    )
  end

  it 'uses date windows for the daily collection' do
    allow(http).to receive(:get).and_return(page(0))
    client.fetch(granularity: 'daily', climate_id: '8403505', from: from, to: to)

    expect(http).to have_received(:get).with(
      'https://api.weather.gc.ca/collections/climate-daily/items',
      params: hash_including(datetime: '2026-10-18/2026-11-02')
    )
  end

  it 'pages until a short page is returned' do
    allow(http).to receive(:get).and_return(page(described_class::PAGE_SIZE), page(3))

    rows = client.fetch(granularity: 'hourly', climate_id: '8403505', from: from, to: to)

    expect(rows.size).to eq(described_class::PAGE_SIZE + 3)
    expect(http).to have_received(:get).with(anything, params: hash_including(offset: described_class::PAGE_SIZE))
  end

  it 'raises a transport error for invalid JSON' do
    allow(http).to receive(:get).and_return('<html>')
    expect { client.fetch(granularity: 'hourly', climate_id: '1', from: from, to: to) }
      .to raise_error(BetterTogether::Weather::Http::Error, /Invalid climate JSON/)
  end
end
