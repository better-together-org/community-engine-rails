# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_plan_price_entry_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_plans_spec.rb.
RSpec.describe 'Documentation screenshots for entering a plan price', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let(:host_platform) { configure_host_platform }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync lookups]) }
  let!(:plan) do
    create(:better_together_billing_plan, :unlinked, platform: host_platform, name: 'Garden plot', identifier: 'garden-plot',
                                                     amount_cents: 12_345, currency: 'USD')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_plans', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def visit_edit
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/plans/#{plan.id}/edit"
    scroll_to(find('#billing-plan-price-fields'), align: :center)
    expect(page).to have_field('billing_plan_amount', with: '123.45')
  end

  it 'captures the price as it is written' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_plan_price_entry',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_plan_price_entry'),
      callouts: [{ id: 'amount', selector: '#billing_plan_amount', title: 'Price as you write it',
                   avoid_container_selector: 'main',
                   bullets: ['Type 45.00; the platform stores it in the right unit for the currency.'] }]
    ) do
      visit_edit
      expect(page).to have_css('#billing_plan_amount')
    end
  end

  it 'captures a refused amount, kept as typed with the reason' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_plan_price_error',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_plan_price_error'),
      callouts: [{ id: 'errors', selector: '#billing-plan-errors', title: 'Why it was refused',
                   bullets: ['What was typed stays in the field, so it can be fixed.'] }]
    ) do
      visit_edit
      fill_in 'billing_plan_amount', with: '4.999'
      click_button 'billing-plan-submit'
      expect(page).to have_css('#billing-plan-errors')
      scroll_to(find('#billing-plan-errors'), align: :top)
    end
  end
end
