# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_not_enabled_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_not_enabled_spec.rb.
RSpec.describe 'Documentation screenshots for billing not enabled and the worker check', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_readiness', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the page a steward sees while billing is off' do
    allow(BetterTogether::Billing::Configuration).to receive_messages(requested?: false, missing_keys: %w[PAY_BUSINESS_NAME])

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_not_enabled',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_not_enabled'),
      callouts: [{ id: 'steps', selector: '#billing-not-enabled-steps', title: 'What is still to set up',
                   position: 'below',
                   bullets: ['Each missing step, in the order to fix it, instead of a page not found.'] }]
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/plans"
      scroll_to(find('#billing-not-enabled-steps'), align: :center)
      expect(page).to have_css('#billing-not-enabled-flag')
    end
  end

  it 'captures the worker row of the readiness checklist' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_readiness_worker',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_readiness_worker'),
      callouts: [{ id: 'worker', selector: '#billing-readiness-worker', title: 'Background worker',
                   position: 'below',
                   bullets: ['Says whether something is taking billing jobs, so paid orders turn into subscriptions.'] }]
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/agreement_requirements"
      scroll_to(find('#billing-readiness-worker'), align: :center)
      expect(page).to have_css('#billing-readiness-worker')
    end
  end
end
