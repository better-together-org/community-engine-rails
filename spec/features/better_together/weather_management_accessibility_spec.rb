# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Host dashboard weather management', :accessibility, :js, :skip_host_setup, :weather_stewards,
               retry: 0 do
  let(:locale) { I18n.default_locale }
  let(:source) { create(:weather_source, identifier: 'eccc-a11y') }
  let!(:location) { create(:weather_location, source:, last_refreshed_at: 5.minutes.ago) }

  before do
    configure_host_platform
    login_as(weather_host_steward, scope: :user)
  end

  def expect_axe_clean
    expect(page).to be_axe_clean.within('main').according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end

  it 'passes WCAG 2.1 AA on the weather tab' do
    visit better_together.host_dashboard_weather_path(locale:)
    expect(page).to have_css('#weather-sources-table', wait: 10)

    expect_axe_clean
  end

  it 'passes WCAG 2.1 AA on the locations of a source' do
    visit better_together.host_dashboard_weather_source_path(source, locale:)
    expect(page).to have_css('#weather-locations-table', wait: 10)

    expect_axe_clean
  end

  it 'confirms, disables a source and records the change, passing WCAG 2.1 AA on the confirm step' do
    visit better_together.host_dashboard_weather_path(locale:)
    find("##{ActionView::RecordIdentifier.dom_id(source)} .weather-source-toggle-btn").click
    expect(page).to have_css('#weather-confirm-effect', wait: 10)
    expect_axe_clean

    click_button 'weather-confirm-btn'

    expect(page).to have_css('#weather-audit-table .weather-audit-row', text: 'eccc-a11y', wait: 10)
    expect(source.reload.enabled).to be(false)
  end
end
