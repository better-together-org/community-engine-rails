# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settlement weather surfaces', :as_platform_manager, :weather_seed do
  let(:locale) { I18n.default_locale }
  let(:settlement) { create(:geography_settlement) }

  around do |example|
    original = BetterTogether.weather_enabled
    example.run
  ensure
    BetterTogether.weather_enabled = original
  end

  def show_page
    get better_together.geography_settlement_path(settlement, locale:)
    Nokogiri::HTML(response.body)
  end

  def weather_panel
    get better_together.weather_geography_settlement_path(settlement, locale:)
  end

  def sql_count(&)
    count = 0
    counter = lambda do |*, payload|
      count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end

  def with_fragment_caching
    caching = ActionController::Base.perform_caching
    store = ActionController::Base.cache_store
    ActionController::Base.perform_caching = true
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    ActionController::Base.perform_caching = caching
    ActionController::Base.cache_store = store
  end

  def cache_round_trip
    weather_panel
    cached = sql_count { weather_panel }
    create(:weather_observation, location:, observed_at: 30.minutes.ago.beginning_of_hour, temperature_c: 30)
    uncached = sql_count { weather_panel }
    [cached, uncached]
  end

  shared_examples 'no weather surfaces' do
    it 'renders no tab, no summary card and no panel route' do
      page = show_page

      expect(page.at_css('#weather-tab')).to be_nil
      expect(page.at_css('#weather')).to be_nil
      expect(page.at_css('#weather-summary-card')).to be_nil
      weather_panel
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'with no weather source' do
    it_behaves_like 'no weather surfaces'
  end

  context 'with a disabled source' do
    before { seed_weather_panel(create(:weather_location, settlement:, source: create(:weather_source, enabled: false))) }

    it_behaves_like 'no weather surfaces'
  end

  context 'with the feature switched off and an enabled source' do
    before do
      seed_weather_panel(create(:weather_location, settlement:))
      BetterTogether.weather_enabled = false
    end

    it_behaves_like 'no weather surfaces'
  end

  context 'with the feature on and an enabled source' do
    let!(:location) { create(:weather_location, settlement:) }

    before { seed_weather_panel(location) }

    it 'renders the tab, the summary card and the panel' do
      page = show_page

      expect(page.at_css('#weather-tab')).to be_present
      expect(page.at_css('#weather-summary-card')).to be_present
      weather_panel
      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).at_css('#weather-panel')).to be_present
    end

    it 'says the station is silent when the source answered after the last observation' do
      location.current_condition.update!(observed_at: 5.hours.ago)
      location.update!(last_refreshed_at: 5.minutes.ago)

      weather_panel

      lead = I18n.t('better_together.weather.panel.station_silent', time: 'TIME', checked: 'CHECKED').split('TIME').first
      expect(Nokogiri::HTML(response.body).at_css('#weather-stale-notice').text.squish).to start_with(lead.strip)
    end

    it 'runs a bounded number of queries however many readings and forecasts are stored' do
      weather_panel
      small = sql_count { weather_panel }

      20.times { |i| create(:weather_forecast, location:, kind: 'daily', issued_at: (i + 2).days.ago, fetched_at: (i + 2).days.ago) }
      (1..14).each do |d|
        [1, 2].each { |h| create(:weather_observation, location:, observed_at: d.days.ago.beginning_of_day + h.hours, temperature_c: d) }
      end
      large = sql_count { weather_panel }

      expect(large).to eq(small)
    end

    it 'serves the panel from the fragment cache and refreshes it when a new observation arrives' do
      cached, uncached = with_fragment_caching { cache_round_trip }

      expect(cached).to be < uncached
    end
  end
end
