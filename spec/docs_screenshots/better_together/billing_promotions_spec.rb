# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_promotions_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_promotions_spec.rb.
RSpec.describe 'Documentation screenshots for promotion codes', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:host_platform) { configure_host_platform }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    BetterTogether::Billing::Promotions::Create.call(platform: host_platform, actor: create(:better_together_person), name: 'Spring drive',
                                                     amount_cents: 1500, currency: 'USD', max_redemptions: 100, credit_expires_after_days: 30)
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_promotions', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the list of promotions and the form that makes one' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_promotions_index',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_promotions_index'),
      callouts: [{ id: 'table', selector: '#billing-promotions-table', title: 'Promotions',
                   bullets: ['Each row shows how many people have used it and whether it is on. The code itself is never shown again.'] },
                 { id: 'new', selector: '#new-promotion-btn', title: 'Make a promotion',
                   bullets: ['The code is shown once when you make it.'] }],
      narrative: {
        title: 'Promotion codes',
        audience: %w[platform_organizer],
        journey_step: 'As a platform organizer, I make codes that give members store credit.',
        callouts: [{ id: 'table', title: 'Use', description: 'Switch a promotion off to stop new redemptions.' }],
        accessibility_notes: 'The table has column headers; the status is text as well as colour.'
      }
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/promotions"
      expect(page).to have_css('#billing-promotions-table')
    end
  end
end
