# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings tab panes', # rubocop:disable RSpec/DescribeClass
               :as_platform_manager, :js, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) { configure_host_platform }

  before { visit better_together.settings_path(locale: I18n.default_locale) }

  it 'renders the usage tab content instead of a missing content notice', :aggregate_failures do
    find('#usage-tab').click

    expect(page).to have_css('#usage.show.active', wait: 10)
    expect(page).to have_css('#usage-settings', text: I18n.t('better_together.settings.usage.none'), wait: 10)
    expect(page).to have_no_text('Content missing')
  end

  it 'renders the cookie consent tab content', :aggregate_failures do
    find('#cookie-consent-tab').click

    expect(page).to have_css('#cookie-consent.show.active', wait: 10)
    expect(page).to have_css('#cookie-consent-settings', visible: :visible, wait: 10)
    expect(page).to have_text(I18n.t('better_together.settings.index.cookie_consent.description'))
  end
end
