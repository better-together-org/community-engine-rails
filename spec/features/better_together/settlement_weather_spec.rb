# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settlement weather tab', :accessibility, :js, :weather_seed, retry: 0 do
  let(:settlement) { create(:geography_settlement) }

  before do
    configure_host_platform
    seed_weather_panel(create(:weather_location, settlement: settlement))
  end

  it 'lazy loads the panel and draws the charts without accessibility violations' do
    visit "/#{I18n.default_locale}/g/settlements/#{settlement.slug}"
    find('#weather-tab').click

    expect(page).to have_css('#weather-panel', wait: 15)
    expect(page).to have_css('#weather-chart-temperature', visible: :all, wait: 10)
    expect(page).to have_css('#weather-chart-precipitation-unreported')
    expect(page).to be_axe_clean.within('#weather').according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end

  it 'opens the weather tab from the current conditions card' do
    visit "/#{I18n.default_locale}/g/settlements/#{settlement.slug}"
    find('#weather-summary-link').click

    expect(page).to have_css('#weather-tab.active', wait: 10)
    expect(page).to have_css('#weather-panel', wait: 15)
  end
end
