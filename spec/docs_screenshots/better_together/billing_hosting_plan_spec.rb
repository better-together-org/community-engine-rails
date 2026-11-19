# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 WORKERS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_hosting_plan_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_hosting_plan_spec.rb.
RSpec.describe 'Documentation screenshots for the hosting plan page', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:hosted) { create(:better_together_platform, :public, name: 'Harbour Arts Collective') }
  let(:password) { 'SecureTest123!@#' }
  let(:email) { 'hosted-steward@example.test' }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    quota_grant(amount: 5_000)
    # The hosted platform answers on the address the browser uses.
    BetterTogether::PlatformDomain.where(platform: host_platform).update_all(hostname: 'host.example.test') # rubocop:disable Rails/SkipsModelValidations
    domain = BetterTogether::PlatformDomain.find_by(platform: hosted, primary_flag: true) ||
             create(:better_together_platform_domain, :primary, platform: hosted)
    domain.update!(hostname: Capybara.server_host)
    user = create(:better_together_user, :confirmed, email:, password:)
    role = BetterTogether::Role.find_by(identifier: 'platform_steward') || create(:better_together_role, identifier: 'platform_steward')
    hosted.person_platform_memberships.create!(member: user.person, role:, status: 'active')

    term = start_subscription(payer: create(:better_together_person))
    attrs = { beneficiary_type: hosted.class.name, beneficiary_id: hosted.id }
    term.update_columns(attrs) # rubocop:disable Rails/SkipsModelValidations
    BetterTogether::Billing::Entitlement.where(pay_subscription_id: term.pay_subscription_id).update_all(attrs) # rubocop:disable Rails/SkipsModelValidations
  end

  it 'captures the plan and usage page' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_hosting_plan',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'platform_steward', feature_set: 'billing_hosting_plan', flow: 'billing_hosting_plan',
                  source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'plan', selector: '[id^="hosting_billing_entitlement"]',
                   title: 'The plan', bullets: ['Its name, whether it is paid up, the price and when it renews.'] },
                 { id: 'usage', selector: '[id^="hosting_usage_billing_entitlement"]', title: 'Usage',
                   bullets: ['How much of each allowance is used.'] }],
      narrative: {
        title: 'Plan and usage',
        audience: %w[platform_organizer],
        journey_step: 'As the steward of a hosted platform, I see the plan the platform is on with the host and how much of it is used.',
        callouts: [{ id: 'plan', title: 'Plan', description: 'One card per plan held for the platform.' }],
        accessibility_notes: 'Usage bars carry a progressbar role and a text label of used and limit.'
      }
    ) do
      capybara_sign_in_user(email, password)
      visit "/#{I18n.default_locale}/billing/hosting_plan"
      expect(page).to have_css('#billing-hosting-plan-page')
    end
  end
end
