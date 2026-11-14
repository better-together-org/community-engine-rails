# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_readiness_plant_link_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_readiness_plant_link_spec.rb.
RSpec.describe 'Documentation screenshots for the readiness link to plant the purchase agreements', # rubocop:disable RSpec/SpecFilePathSuffix
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
    host_platform.billing_agreement_requirements.destroy_all
    BetterTogether::Agreement.where(platform: host_platform,
                                    identifier: %w[subscription_agreement one_time_purchase_agreement offline_payment_terms]).destroy_all
  end

  after { Current.platform = nil }

  it 'captures the checklist with the link to plant the agreements' do # rubocop:disable RSpec/NoExpectationExample
    target = '#billing-readiness-plant-agreements-subscription'
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_readiness_plant_link', device: :both,
                                      metadata: { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_readiness',
                                                  flow: 'billing_readiness_plant_link', source_spec: self.class.metadata[:file_path] },
                                      callouts: [{ id: 'plant_link', selector: target, title: 'Plant the agreements',
                                                   avoid_container_selector: 'main',
                                                   bullets: ['Opens the seed catalog at the billing agreements section.'] }]
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/agreement_requirements"
      scroll_to(find(target), align: :center)
      expect(page).to have_css(target)
    end
  end
end
