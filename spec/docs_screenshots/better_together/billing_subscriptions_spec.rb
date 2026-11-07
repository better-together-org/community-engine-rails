# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_subscriptions_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_subscriptions_spec.rb.
RSpec.describe 'Documentation screenshots for subscriptions', # rubocop:disable RSpec/SpecFilePathSuffix
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
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_subscriptions', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the steward\'s list of subscribers and their filters' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_subscribers_index',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_subscribers_index'),
      callouts: [{ id: 'filters', selector: '#billing-subscribers-filters', title: 'Who needs attention',
                   bullets: ['Past due means a renewal is unpaid inside its extra time; lapsed means the extra time ran out.'] }],
      narrative: {
        title: 'Subscribers',
        audience: %w[platform_organizer],
        journey_step: 'As a platform organizer, I see whose renewal is overdue and can cover, extend or cancel it.',
        callouts: [{ id: 'filters', title: 'Filters', description: 'Each filter follows the state Pay records for the subscription.' }],
        accessibility_notes: 'The filters are links with text; the state is text as well as colour.'
      }
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/subscribers"
      expect(page).to have_css('#billing-subscribers-filters')
    end
  end
end
