# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_tax_addresses_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_checkout_address_spec.rb and billing_tax_registrations_spec.rb.
RSpec.describe 'Documentation screenshots for tax registrations and the billing address', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:cash_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     name: 'Garden plot', currency: 'USD', amount_cents: 2500)
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    purchase_agreements_for(host_platform)
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_tax', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def visit_billing(path)
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/#{path}"
  end

  it 'captures choosing the billing address at checkout' do
    manager = BetterTogether::User.find_by!(email: 'manager@example.test').person
    first = create_billing_address_for(manager)
    BetterTogether::Billing::DefaultAddress.set!(platform: host_platform, person: manager, address: first, kind: 'billing')

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_checkout_address',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_checkout_address'),
      callouts: [{ id: 'address', selector: '#billing-checkout-address', title: 'Billing address',
                   bullets: ['Pick one of your addresses, or add a new one. Tax is worked out for its place.'] }]
    ) do
      visit_billing("checkout/new?plan_id=#{cash_plan.id}&payment_method=cash")
      scroll_to(find('#billing-checkout-address'), align: :top)
      expect(page).to have_css('#billing-checkout-address-select', visible: :all)
    end
  end

  it 'captures the tax registrations list' do
    create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA')

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_tax_registrations',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_tax_registrations'),
      callouts: [{ id: 'table', selector: '#billing-tax-registrations-table', title: 'Where you collect tax',
                   bullets: ['Status, whether prices include tax, and when each registration is in force.'] }]
    ) do
      visit_billing('tax_registrations')
      expect(page).to have_css('#billing-tax-registrations-table')
    end
  end

  it 'captures adding a tax registration' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_tax_registration_form',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_tax_registration_form'),
      callouts: [{ id: 'form', selector: '#billing-tax-registration-form', title: 'Registration details',
                   bullets: ['Place, status, tax-inclusive pricing and dates.'] }]
    ) do
      visit_billing('tax_registrations/new')
      expect(page).to have_css('#billing-tax-registration-form')
    end
  end
end
