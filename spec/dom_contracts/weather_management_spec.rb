# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the host dashboard Weather tab: ids and classes the screenshot and feature specs target.
RSpec.describe 'Host dashboard weather management DOM contract', :skip_host_setup, :weather_stewards, # rubocop:disable RSpec/DescribeClass
               type: :request do
  let(:locale) { I18n.default_locale }
  let(:page_html) { Nokogiri::HTML(response.body) }
  let(:source) { create(:weather_source, identifier: 'contract-source') }
  let!(:location) { create(:weather_location, source:, last_refreshed_at: 5.minutes.ago) }

  around do |example|
    original = BetterTogether.weather_enabled
    example.run
  ensure
    BetterTogether.weather_enabled = original
  end

  before do
    configure_host_platform
    sign_in weather_host_steward
  end

  def dom_id(record) = ActionView::RecordIdentifier.dom_id(record)

  it 'renders the tab inside the host dashboard frame with its sections', :aggregate_failures do
    get better_together.host_dashboard_weather_path(locale:)

    frame = page_html.at_css('turbo-frame#host-dashboard-tab-content')
    expect(frame.at_css('#weather-management h1#weather-management-heading')).to be_present
    %w[#weather-feature-switch #weather-feature-status-badge a#weather-feature-toggle-btn
       #weather-sources table#weather-sources-table #weather-audit #weather-audit-empty].each do |selector|
      expect(frame.at_css(selector)).to be_present, selector
    end
  end

  it 'gives each source row stable ids and classes', :aggregate_failures do
    get better_together.host_dashboard_weather_path(locale:)

    row = page_html.at_css("tr##{dom_id(source)}.weather-source-row")
    %w[.weather-source-identifier .weather-source-adapter .weather-status-badge .weather-source-location-count
       .weather-source-last-refresh .weather-source-last-success .weather-source-actions
       a.weather-source-locations-link a.weather-source-toggle-btn].each do |selector|
      expect(row.at_css(selector)).to be_present, selector
    end
  end

  it 'gives the locations table stable ids and classes', :aggregate_failures do
    get better_together.host_dashboard_weather_source_path(source, locale:)

    expect(page_html.at_css('#weather-source-detail a#weather-back-link')).to be_present
    row = page_html.at_css("table#weather-locations-table tr##{dom_id(location)}.weather-location-row")
    %w[.weather-location-name .weather-location-ref .weather-status-badge .weather-location-last-refresh
       .weather-location-last-success a.weather-location-toggle-btn].each do |selector|
      expect(row.at_css(selector)).to be_present, selector
    end
  end

  it 'renders the confirm step with its banner, form and cancel link', :aggregate_failures do
    get better_together.confirm_host_dashboard_weather_source_path(source, enabled: false, locale:)

    %w[#weather-confirm h1#weather-confirm-heading #weather-confirm-effect.alert-warning
       form#weather-confirm-form button#weather-confirm-btn a#weather-confirm-cancel].each do |selector|
      expect(page_html.at_css(selector)).to be_present, selector
    end
  end

  it 'renders the env kill switch notice and a disabled switch button', :aggregate_failures do
    BetterTogether.weather_enabled = false
    get better_together.host_dashboard_weather_path(locale:)

    button = page_html.at_css('button#weather-feature-toggle-btn')
    expect(button['aria-describedby']).to eq('weather-env-kill-switch-notice')
    expect(page_html.at_css('#weather-env-kill-switch-notice[role="status"]')).to be_present
  end
end
