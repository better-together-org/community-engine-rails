# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the settlement weather tab and its lazily loaded panel. Everything is read from stored rows.
RSpec.describe 'Settlement weather panel DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:settlement) { create(:geography_settlement) }
  let(:now) { Time.current }
  let(:page_html) { Nokogiri::HTML(response.body) }

  def show_path
    better_together.geography_settlement_path(settlement, locale:)
  end

  def weather_path
    better_together.weather_geography_settlement_path(settlement, locale:)
  end

  def seed_weather(location)
    create(:weather_current_condition, location: location, observed_at: now, fetched_at: now,
                                       payload: { 'values' => { 'temperature_c' => 4.0, 'humidity_pct' => 80 },
                                                  'condition' => 'Cloudy', 'extras' => {} })
    create(:weather_forecast, location: location, kind: 'hourly', payload: { 'periods' => [
             { 'starts_at' => (now.beginning_of_hour + 1.hour).iso8601, 'temperature_c' => 3 }
           ] })
    create(:weather_forecast, location: location, kind: 'daily', payload: { 'periods' => [
             { 'name' => 'Tonight', 'summary' => 'Rain', 'temperature_c' => 2 }
           ] })
    create(:weather_observation, location: location, observed_at: now - 1.day, temperature_c: 5.0)
  end

  describe 'settlement page' do
    it 'has no weather tab without an enabled weather location', :aggregate_failures do
      get show_path

      expect(response).to have_http_status(:ok)
      expect(page_html.at_css('#weather-tab')).to be_nil
      expect(page_html.at_css('#weather')).to be_nil
    end

    it 'has no weather tab when the location is disabled' do
      create(:weather_location, settlement: settlement, enabled: false)
      get show_path

      expect(page_html.at_css('#weather-tab')).to be_nil
    end

    it 'adds a weather tab and a lazy frame for an enabled location', :aggregate_failures do
      create(:weather_location, settlement: settlement)
      get show_path

      expect(page_html.at_css('#weather-tab')['href']).to eq('#weather')
      frame = page_html.at_css('#weather turbo-frame#settlement-weather')
      expect(frame['src']).to include("/settlements/#{settlement.slug}/weather")
      expect(frame['loading']).to eq('lazy')
    end
  end

  describe 'current conditions card on the about tab' do
    it 'is absent without stored current conditions' do
      create(:weather_location, settlement: settlement)
      get show_path

      expect(page_html.at_css('#weather-summary-card')).to be_nil
    end

    it 'shows conditions and links to the weather tab', :aggregate_failures do
      seed_weather(create(:weather_location, settlement: settlement))
      get show_path

      card = page_html.at_css('#about #weather-summary-card')
      expect(card).to be_present
      %w[#weather-summary-temperature #weather-summary-condition #weather-summary-observed
         #weather-summary-attribution].each { |selector| expect(card.at_css(selector)).to be_present }
      expect(card.at_css('#weather-summary-details')).to be_nil
      expect(card.at_css('#weather-summary-link')['href']).to eq('#weather')
    end
  end

  describe 'GET weather' do
    it 'is not found without an enabled weather location' do
      get weather_path

      expect(response).to have_http_status(:not_found)
    end

    it 'shows the empty state with attribution when nothing is stored', :aggregate_failures do
      create(:weather_location, settlement: settlement)
      get weather_path

      expect(response).to have_http_status(:ok)
      expect(page_html.at_css('turbo-frame#settlement-weather #weather-panel')).to be_present
      expect(page_html.at_css('#weather-empty')).to be_present
      expect(page_html.at_css('#weather-current')).to be_nil
      expect(page_html.at_css('#weather-attribution')).to be_present
    end

    context 'with stored data' do
      before do
        seed_weather(create(:weather_location, settlement: settlement))
        get weather_path
      end

      it 'renders the sections with stable ids', :aggregate_failures do
        %w[#weather-current #weather-current-temperature #weather-current-condition #weather-hourly
           #weather-hourly-list #weather-daily #weather-daily-table #weather-history #weather-history-table
           #weather-history-data #weather-attribution #weather-licence-link].each do |selector|
          expect(page_html.at_css(selector)).to be_present, "missing #{selector}"
        end
      end

      it 'wires the charts controller with series data and a canvas per measure', :aggregate_failures do
        history = page_html.at_css('#weather-history')
        expect(history['data-controller']).to eq('better-together--weather-charts')
        %w[temperature precipitation wind].each do |name|
          card = page_html.at_css("#weather-chart-#{name}-card")
          expect(card).to be_present
          expect(card.at_css("canvas#weather-chart-#{name}, #weather-chart-#{name}-unreported")).to be_present
        end
      end

      it 'does not show the stale or error notices' do
        expect([page_html.at_css('#weather-stale-notice'), page_html.at_css('#weather-source-error')]).to all(be_nil)
      end

      it 'does not chart a measurement the station did not report' do
        expect(page_html.at_css('#weather-chart-precipitation-unreported')).to be_present
      end
    end

    it 'shows a stale notice when the stored conditions are old', :aggregate_failures do
      location = create(:weather_location, settlement: settlement)
      create(:weather_current_condition, location: location, observed_at: now - 1.day, fetched_at: now - 1.day)
      get weather_path

      expect(page_html.at_css('#weather-stale-notice')).to be_present
    end

    it 'shows a source error notice after a failed update' do
      create(:weather_location, settlement: settlement, last_error_at: now, last_error: 'timeout')
      get weather_path

      expect(page_html.at_css('#weather-source-error')).to be_present
    end

    it 'never calls the weather source' do
      seed_weather(create(:weather_location, settlement: settlement))
      allow(SsrfFilter).to receive(:get).and_raise('network used')

      get weather_path

      expect(response).to have_http_status(:ok)
    end

    %i[es fr uk].each do |other|
      it "renders in #{other}" do
        seed_weather(create(:weather_location, settlement: settlement))
        get better_together.weather_geography_settlement_path(settlement, locale: other)

        expect_html_content(I18n.t('better_together.weather.panel.current.heading', locale: other))
      end
    end
  end
end
