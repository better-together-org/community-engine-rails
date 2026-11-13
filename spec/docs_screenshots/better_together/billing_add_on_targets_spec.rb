# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_add_on_targets_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_add_on_targets_spec.rb.
RSpec.describe 'Documentation screenshots for add-on targets', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:attrs) { { platform: host_platform, processor: nil, accepted_payment_methods: %w[cash], currency: 'USD' } }
  let(:add_on) do
    create(:better_together_billing_plan, :unlinked, :one_time, **attrs, add_on: true, amount_cents: 700, name: 'Conference lunch')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    sub_plan.update!(name: 'Supporting member')
    BetterTogether::Billing::PlanAddOn.create!(plan: sub_plan, add_on:)
  end

  after { Current.platform = nil }

  it 'captures the extras a plan holder can add later, on the billing page' do
    start_subscription(payer: find_or_create_test_user('user@example.test', 'SecureTest123!@#').person)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_hub_add_ons',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'user', feature_set: 'billing_add_on_targets', flow: 'billing_hub_add_ons',
                  source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'extras', selector: '#billing-hub-add-ons', title: 'Extras for your plans',
                   bullets: ['One-time extras for a plan you already hold, bought on their own.'] }],
      narrative: {
        title: 'Extras on the billing page',
        audience: %w[end_user],
        journey_step: 'As a member with a plan, I come back later and add an extra without buying the plan again.',
        callouts: [{ id: 'extras', title: 'Extras', description: 'Each extra links straight into checkout.' }],
        accessibility_notes: 'The section is labelled by its heading; each extra has a text button.'
      }
    ) do
      capybara_login_as_user
      visit "/#{I18n.default_locale}/billing"
      expect(page).to have_css('#billing-hub-add-ons')
      page.execute_script("document.querySelector('#billing-hub-add-ons').scrollIntoView({block: 'center'})")
    end
  end

  it 'captures the steward choosing which plans an add-on extends' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_add_on_targets_form',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_add_on_targets',
                  flow: 'billing_add_on_targets_form', source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'targets', selector: '#billing-plan-add-on-targets', title: 'Plans this add-on extends',
                   bullets: ['Ticked plans offer the add-on, and their holders may buy it alone later.'] }],
      narrative: {
        title: 'Add-on target plans',
        audience: %w[platform_organizer],
        journey_step: 'As a steward I choose which plans an add-on extends.',
        callouts: [{ id: 'targets', title: 'Target plans', description: 'None ticked means every plan.' }],
        accessibility_notes: 'A labelled fieldset of checkboxes with a hint.'
      }
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/plans/#{add_on.id}/edit"
      expect(page).to have_css('#billing-plan-add-on-targets')
      page.execute_script("document.querySelector('#billing-plan-add-on-targets').scrollIntoView({block: 'center'})")
    end
  end
end
