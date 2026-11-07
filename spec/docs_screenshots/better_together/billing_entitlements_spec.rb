# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_entitlements_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_entitlements_spec.rb.
RSpec.describe 'Documentation screenshots for entitlements and allowances', # rubocop:disable RSpec/SpecFilePathSuffix
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
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_entitlements', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the steward\'s allowances page: how strictly each quota is enforced, and who has paid for more' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_allowances_index',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_allowances_index'),
      callouts: [{ id: 'enforcement', selector: '#billing-allowances-enforcement', title: 'How strictly',
                   bullets: ['Shadow counts use but never refuses anything. Hard refuses new use past the limit.'] }],
      narrative: {
        title: 'Allowances and usage',
        audience: %w[platform_organizer],
        journey_step: 'As a platform organizer, I choose how strictly quotas are enforced and see who has paid for more.',
        callouts: [{ id: 'enforcement', title: 'Enforcement', description: 'Nothing already stored is ever deleted when a limit drops.' }],
        accessibility_notes: 'Each choice has a label; the usage meter has a text label as well as a bar.'
      }
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/allowances"
      expect(page).to have_css('#billing-allowances-enforcement')
    end
  end
end
