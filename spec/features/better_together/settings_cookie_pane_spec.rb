# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings cookie consent pane', # rubocop:disable RSpec/DescribeClass
               :as_platform_manager, :js, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) { configure_host_platform }

  before do
    BetterTogether.register_consent_provider(:google_analytics) { :analytics }
    visit better_together.settings_path(locale: I18n.default_locale)
  end

  after { BetterTogether::Consent.reset! }

  it 'stays visible when a cookie-notice filter hides #cookie-consent', :aggregate_failures do
    page.execute_script(<<~JS)
      var s = document.createElement('style');
      s.textContent = '#cookie-consent{display:none !important}';
      document.head.appendChild(s);
    JS
    find('#cookie-consent-tab').click

    expect(page).to have_css('#consent-preferences.show.active', wait: 10)
    expect(page).to have_css('#cookie-consent-form', visible: :visible, wait: 10)
    expect(page).to have_text(I18n.t('better_together.settings.index.cookie_consent.title'))
  end
end
