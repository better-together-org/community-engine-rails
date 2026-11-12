# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 WORKERS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_hosted_billing_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_hosted_billing_spec.rb.
RSpec.describe 'Documentation screenshots for hosted billing enablement', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with billing switched on'

  let!(:host_platform) { configure_host_platform }
  let(:hosted_one) { create(:better_together_platform, :public, name: 'Harbour Arts Collective') }
  let(:hosted_two) { create(:better_together_platform, :public, name: 'Signal Hill Co-op') }
  let(:hosted_three) { create(:better_together_platform, :public, name: 'Bay Roads Society') }
  let!(:agreements) { BetterTogether::Billing::HostedAgreementSeeds.call(host_platform) }
  let(:person) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager).person }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    agreements.each_value { |agreement| agreement.update!(lifecycle_state: 'active') }
    billing = BetterTogether::Billing::HostedBilling
    billing.accept!(platform: hosted_one, mode: :billing, person:)
    billing.accept!(platform: hosted_one, mode: :local, person:)
    billing.accept!(platform: hosted_two, mode: :billing, person:)
    hosted_three
    billing.accept!(platform: hosted_three, mode: :billing, person:)
    billing.suspend!(platform: hosted_three, by: person, reason: 'Hosting fees unpaid since March')
  end

  it 'captures the host steward page of hosted platforms' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_hosted_platforms',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_hosted', flow: 'billing_hosted_platforms',
                  source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'table', selector: '#billing-hosted-platforms-table', title: 'Every hosted platform',
                   bullets: ['Which agreements each platform has accepted and whether its billing is on.'] },
                 { id: 'suspend', selector: "##{ActionView::RecordIdentifier.dom_id(hosted_one, :hosted_suspend)}", title: 'Suspend billing',
                   bullets: ['Needs a reason. Pauses the platform\'s billing and keeps its data.'] }],
      narrative: {
        title: 'Hosted platforms',
        audience: %w[platform_organizer],
        journey_step: 'As the host steward, I see what each hosted platform has agreed to and can suspend a platform\'s billing.',
        callouts: [{ id: 'table', title: 'Status', description: 'One row per hosted platform.' }],
        accessibility_notes: 'The table has column headers and row headers; the suspend field is labelled.'
      }
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/hosted_platforms"
      expect(page).to have_css('#billing-hosted-platforms-table')
      page.execute_script("document.querySelector('#billing-hosted-platforms-table').scrollIntoView({block: 'center'})")
    end
  end
end
