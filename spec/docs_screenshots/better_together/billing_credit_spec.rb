# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_credit_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_credit_spec.rb.
RSpec.describe 'Documentation screenshots for store credit', # rubocop:disable RSpec/SpecFilePathSuffix
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
  let(:holder) { create(:better_together_person, name: 'Sam Rivera') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    steward = create(:better_together_person)
    credit = BetterTogether::Billing::Credit
    credit::Grant.call(platform: host_platform, holder:, amount_cents: 5000, currency: 'USD', origin: 'steward_grant', actor: steward,
                       idempotency_key: 'screenshot-1', expires_at: 20.days.from_now, note: 'Thanks for volunteering')
    credit::Grant.call(platform: host_platform, holder:, amount_cents: 1500, currency: 'USD', origin: 'steward_grant', actor: steward,
                       idempotency_key: 'screenshot-2')
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_store_credit', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the steward finding a person and giving credit' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_credit_accounts_lookup',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_credit_accounts_lookup'),
      callouts: [{ id: 'lookup', selector: '#billing-credit-lookup-form', title: 'Find a person',
                   bullets: ['Type the whole handle. There is no search, so people cannot be browsed.'] },
                 { id: 'grant', selector: '#billing-credit-grant-form', title: 'Give credit',
                   bullets: ['Credit can expire after a number of days. You cannot give it to yourself.'] }],
      narrative: {
        title: 'Giving store credit',
        audience: %w[platform_organizer],
        journey_step: 'As a platform organizer, I give a member credit they can spend on what the platform sells.',
        callouts: [{ id: 'grant', title: 'Grant', description: 'The member is told, and sees it on their credit page.' }],
        accessibility_notes: 'Every field has a visible label; results are plain text.'
      }
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/credit_accounts?handle=#{holder.identifier}"
      expect(page).to have_css('#billing-credit-grant-form')
      page.execute_script("document.querySelector('#billing-credit-grant-form').scrollIntoView({block: 'center'})")
    end
  end
end
