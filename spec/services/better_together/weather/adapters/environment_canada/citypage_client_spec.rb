# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::Adapters::EnvironmentCanada::CitypageClient do
  subject(:client) { described_class.new(http: http) }

  let(:base) { described_class::BASE_URL }
  let(:now) { Time.utc(2026, 11, 2, 17, 20) }
  let(:newest) { '20261102T170153.072Z_MSC_CitypageWeather_s0000221_en.xml' }
  let(:older) { '20261102T160132.045Z_MSC_CitypageWeather_s0000221_en.xml' }
  let(:other_site) { '20261102T175000.000Z_MSC_CitypageWeather_s0000280_en.xml' }
  let(:pages) do
    {
      "#{base}/NL/17/" => %(<a href="#{newest}">x</a><a href="#{other_site}">y</a><a href="#{newest}">dup</a>),
      "#{base}/NL/16/" => %(<a href="#{older}">x</a>),
      "#{base}/NL/15/" => :not_found,
      "#{base}/NL/17/#{newest}" => nil
    }
  end
  let(:http) { instance_double(BetterTogether::Weather::Http) }

  before do
    pages["#{base}/NL/17/#{newest}"] = weather_fixture('citypage_corner_brook_en.xml')
    allow(http).to receive(:get) do |url|
      page = pages.fetch(url)
      raise BetterTogether::Weather::Http::NotFound, url if page == :not_found

      page
    end
  end

  it 'downloads the newest file for the requested site only' do
    expect(client.fetch(site_ref: 'NL/s0000221', now: now)).to include('<siteData')
    expect(http).to have_received(:get).with("#{base}/NL/17/#{newest}")
  end

  it 'raises when no file exists for the site' do
    expect { client.fetch(site_ref: 'NL/s0000999', now: now) }
      .to raise_error(BetterTogether::Weather::Http::Error, /No citypage file/)
  end

  it 'raises StaleData when the newest document is older than the allowed age' do
    pages["#{base}/NL/17/#{newest}"] = weather_fixture('citypage_corner_brook_en.xml')
                                       .sub('<timeStamp>20261102170153</timeStamp>', '<timeStamp>20261102100153</timeStamp>')

    expect { client.fetch(site_ref: 'NL/s0000221', now: now) }.to raise_error(described_class::StaleData)
  end

  it 'rejects a site_ref without a province' do
    expect { client.fetch(site_ref: 's0000221', now: now) }.to raise_error(ArgumentError)
  end
end
