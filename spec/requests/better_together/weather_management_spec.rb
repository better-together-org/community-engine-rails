# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Host dashboard weather management', :skip_host_setup, :weather_stewards do
  let(:locale) { I18n.default_locale }
  let(:host_platform) { configure_host_platform }
  let(:steward) { weather_host_steward }
  let(:page_html) { Nokogiri::HTML(response.body) }

  around do |example|
    original = BetterTogether.weather_enabled
    example.run
  ensure
    BetterTogether.weather_enabled = original
  end

  before { host_platform }

  def paths
    better_together
  end

  def count_queries(&)
    queries = []
    callback = lambda do |*, payload|
      queries << payload[:sql] unless payload[:name] == 'SCHEMA' || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &)
    queries.size
  end

  def seed_sources(source_count, locations_per_source)
    Array.new(source_count) do
      create(:weather_source).tap do |source|
        locations_per_source.times { create_bare_location(source) }
      end
    end
  end

  # Many settlements: skip the country and state factories, whose random ISO codes can collide.
  def create_bare_location(source)
    settlement = create(:geography_settlement, :without_country, :without_state)
    create(:weather_location, source:, settlement:, last_refreshed_at: 5.minutes.ago)
  end

  context 'when signed in as a host steward' do
    before { sign_in steward }

    it 'lists sources with location counts, refresh times and a stale flag', :aggregate_failures do
      fresh = create(:weather_source, identifier: 'fresh-source')
      create(:weather_location, source: fresh, last_refreshed_at: 5.minutes.ago)
      create(:weather_location, source: fresh, enabled: false)
      stale = create(:weather_source, identifier: 'stale-source')
      create(:weather_location, source: stale, last_refreshed_at: 3.hours.ago, last_error_at: 10.minutes.ago)

      get paths.host_dashboard_weather_path(locale:)

      expect(response).to have_http_status(:ok)
      fresh_row = page_html.at_css("##{ActionView::RecordIdentifier.dom_id(fresh)}")
      stale_row = page_html.at_css("##{ActionView::RecordIdentifier.dom_id(stale)}")
      expect(fresh_row.at_css('.weather-source-location-count').text.squish).to eq('1 of 2 enabled')
      expect(fresh_row.at_css('.weather-stale-badge')).to be_nil
      expect(stale_row.at_css('.weather-stale-badge')).to be_present
      expect(stale_row.at_css('.weather-source-last-refresh time')).to be_present
    end

    it 'loads the source list with a query count that does not grow with sources or locations' do
      seed_sources(2, 1)
      get paths.host_dashboard_weather_path(locale:)
      small = count_queries { get paths.host_dashboard_weather_path(locale:) }

      seed_sources(4, 3)
      large = count_queries { get paths.host_dashboard_weather_path(locale:) }

      expect(large).to eq(small)
    end

    it 'loads a source locations page with a query count that does not grow with locations' do
      source = seed_sources(1, 2).first
      get paths.host_dashboard_weather_source_path(source, locale:)
      small = count_queries { get paths.host_dashboard_weather_source_path(source, locale:) }

      5.times { create_bare_location(source) }
      large = count_queries { get paths.host_dashboard_weather_source_path(source, locale:) }

      expect(large).to eq(small)
    end

    it 'shows a confirm step stating the effect before switching weather off', :aggregate_failures do
      get paths.confirm_host_dashboard_weather_feature_path(enabled: false, locale:)

      expect(response).to have_http_status(:ok)
      expect(page_html.at_css('#weather-confirm-effect').text).to include('stops every weather job')
      expect(page_html.at_css('#weather-confirm-form')['action'])
        .to eq(paths.host_dashboard_weather_feature_path(locale:))
      expect(host_platform.reload.weather_enabled).to be(true)
    end

    it 'persists the host switch, audits it and hides settlement weather', :aggregate_failures do
      location = create(:weather_location)

      patch paths.host_dashboard_weather_feature_path(locale:), params: { enabled: 'false' }

      expect(response).to redirect_to(paths.host_dashboard_weather_path(locale:))
      expect(host_platform.reload.weather_enabled).to be(false)
      expect(BetterTogether::Weather).not_to be_enabled
      activity = BetterTogether::Activity.find_by!(key: 'weather.feature.toggled')
      expect(activity.owner).to eq(steward.person)
      expect(activity.parameters).to include('before' => true, 'after' => false)

      get paths.geography_settlement_path(location.settlement, locale:)
      expect(page_html.at_css('#weather-tab')).to be_nil
    end

    it 'persists a source toggle and lists it in the change history', :aggregate_failures do
      source = create(:weather_source, identifier: 'eccc-test')

      patch paths.host_dashboard_weather_source_path(source, locale:), params: { enabled: 'false' }
      follow_redirect!

      expect(source.reload.enabled).to be(false)
      row = page_html.at_css('#weather-audit-table .weather-audit-row')
      expect(row.at_css('.weather-audit-target').text).to include('eccc-test')
      expect(row.at_css('.weather-audit-change').text.squish).to eq('Enabled to Disabled')
      expect(row.at_css('.weather-audit-actor').text.squish).to eq(steward.person.name)
    end

    it 'persists a location toggle and returns to its source', :aggregate_failures do
      location = create(:weather_location)

      patch paths.host_dashboard_weather_location_path(location, locale:), params: { enabled: 'false' }

      expect(response).to redirect_to(paths.host_dashboard_weather_source_path(location.source, locale:))
      expect(location.reload.enabled).to be(false)
      expect(BetterTogether::Activity.find_by!(trackable: location).key).to eq('weather.location.toggled')
    end

    it 'expires the cached switch so the next check sees the change at once' do
      memory_cache = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(memory_cache)
      expect(BetterTogether::Weather.feature_enabled?).to be(true)

      patch paths.host_dashboard_weather_feature_path(locale:), params: { enabled: 'false' }

      expect(BetterTogether::Weather.feature_enabled?).to be(false)
    end

    context 'when the env kill switch is set' do
      before { BetterTogether.weather_enabled = false }

      it 'shows the server setting and disables the switch', :aggregate_failures do
        get paths.host_dashboard_weather_path(locale:)

        expect(page_html.at_css('#weather-env-kill-switch-notice').text).to include('BETTER_TOGETHER_WEATHER_ENABLED')
        expect(page_html.at_css('button#weather-feature-toggle-btn')['disabled']).to be_present
        expect(page_html.at_css('#weather-feature-status-badge').text.squish).to eq('Off (server setting)')
      end

      it 'wins over a dashboard setting that is on and refuses changes', :aggregate_failures do
        patch paths.host_dashboard_weather_feature_path(locale:), params: { enabled: 'true' }

        expect(flash[:alert]).to be_present
        expect(host_platform.reload.weather_enabled).to be(true)
        expect(BetterTogether::Weather.feature_enabled?).to be(false)
        expect(BetterTogether::Activity.where(key: 'weather.feature.toggled')).to be_empty
      end
    end
  end

  context 'when signed in as an ordinary host member' do
    before { sign_in weather_host_member }

    it 'denies the tab and changes', :aggregate_failures do
      source = create(:weather_source)

      get paths.host_dashboard_weather_path(locale:)
      expect(response).not_to have_http_status(:ok)

      patch paths.host_dashboard_weather_source_path(source, locale:), params: { enabled: 'false' }
      expect(source.reload.enabled).to be(true)
    end
  end

  context "when signed in as another platform's steward" do
    before { sign_in weather_other_platform_steward }

    it 'denies changing the host switch' do
      patch paths.host_dashboard_weather_feature_path(locale:), params: { enabled: 'false' }

      expect(host_platform.reload.weather_enabled).to be(true)
    end
  end

  context 'when not signed in' do
    it 'does not expose the tab' do
      get paths.host_dashboard_weather_path(locale:)

      expect(response).not_to have_http_status(:ok)
    end
  end
end
