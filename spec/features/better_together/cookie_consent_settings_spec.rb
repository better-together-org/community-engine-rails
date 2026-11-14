# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cookie consent settings', # rubocop:disable RSpec/DescribeClass
               :accessibility, :as_user, :js, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) { configure_host_platform }
  let(:wcag) { %i[wcag2a wcag2aa wcag21a wcag21aa] }

  before { BetterTogether.register_consent_provider(:all) { true } }

  after { BetterTogether::Consent.reset! }

  def open_tab
    visit better_together.settings_path(locale: I18n.default_locale)
    find('#cookie-consent-tab').click
    expect(page).to have_css('#cookie-consent-form', visible: :visible, wait: 10)
  end

  it 'passes WCAG 2.1 AA', :aggregate_failures do
    open_tab
    expect(page).to be_axe_clean.within('#cookie-consent-settings').according_to(*wcag)
  end

  it 'saves to the account and the cookie, announces the change and reports the status', :aggregate_failures do
    open_tab
    page.execute_script("window.addEventListener('better_together:consent', e => { sessionStorage.setItem('heard', JSON.stringify(e.detail)) })")
    find('label[for="cookie-consent-analytics"]').click
    click_button 'cookie-consent-save'

    expect(page).to have_css('#cookie-consent-status', text: I18n.t('better_together.consent.saved'), wait: 10)
    expect(JSON.parse(page.evaluate_script("sessionStorage.getItem('heard')")))
      .to eq('analytics' => true, 'marketing' => false)

    open_tab
    expect(find('#cookie-consent-analytics')).to be_checked
    expect(find('#cookie-consent-marketing')).not_to be_checked
  end

  it 'withdraws all optional consent', :aggregate_failures do
    open_tab
    find('label[for="cookie-consent-marketing"]').click
    click_button 'cookie-consent-save'
    expect(page).to have_css('#cookie-consent-status', text: I18n.t('better_together.consent.saved'), wait: 10)

    click_button 'cookie-consent-withdraw'
    expect(page).to have_css('#cookie-consent-status', text: I18n.t('better_together.consent.saved'), wait: 10)
    expect(find('#cookie-consent-marketing')).not_to be_checked
    expect(find('#cookie-consent-analytics')).not_to be_checked
  end

  it 'stores a banner choice made while signed in on the account', :aggregate_failures do
    visit better_together.settings_path(locale: I18n.default_locale)
    find('#consent-accept-all').click
    expect(page).to have_css('#consent-preferences-link', visible: :visible, wait: 10)

    page.driver.browser.manage.delete_cookie(BetterTogether::Consent::COOKIE)
    open_tab
    expect(find('#cookie-consent-analytics')).to be_checked
    expect(find('#cookie-consent-marketing')).to be_checked
    expect(page).to have_no_css('#consent-banner', visible: :visible)
  end
end
