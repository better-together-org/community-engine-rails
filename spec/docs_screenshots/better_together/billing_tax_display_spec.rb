# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/NoExpectationExample
# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_tax_display_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_orders_spec.rb and the checkout request spec.
RSpec.describe 'Documentation screenshots for tax on checkout, sales and orders', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::BillingAddressHelpers

  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:order) { place_offline('cash', tax_address: { country_iso: 'CA', region_code: 'NL' }) }
  let(:dom_id) { ActionView::RecordIdentifier }
  let(:metadata) do
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_tax', source_spec: self.class.metadata[:file_path] }
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA')
    zone = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA', region_code: 'NL')
    create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, label: 'HST', rate: 0.15)
    order
  end

  after { Current.platform = nil }

  def capture(name, target, title, bullet, path)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name, device: :both, metadata: metadata.merge(flow: name),
            callouts: [{ id: name, selector: target, title:, avoid_container_selector: 'main', bullets: [bullet] }]
    ) do
      capybara_login_as_platform_manager
      yield if block_given?
      visit path
      scroll_to(find(target), align: :center)
      expect(page).to have_css(target)
    end
  end

  it 'captures the tax breakdown on a sale' do
    capture('billing_tax_order_breakdown', "##{dom_id.dom_id(order, :tax)}", 'Tax on an order',
            'Subtotal, each tax with its rate, then the total.', "/#{I18n.default_locale}/billing/sales/#{order.id}")
  end

  it 'captures the tax column on the sales list' do
    capture('billing_tax_sales_column', "##{dom_id.dom_id(order)} .billing-sale-tax", 'Tax per sale',
            'Sales that carry no tax show a dash.', "/#{I18n.default_locale}/billing/sales")
  end

  it 'captures the tax and total on the checkout summary' do
    enable_offline('cash')
    plan
    person = BetterTogether::User.find_by!(email: 'manager@example.test').person
    create_billing_address_for(person)

    capture('billing_tax_checkout_summary', '#billing-checkout-tax', 'Tax before paying',
            'The tax for the chosen billing address and the total it makes.',
            "/#{I18n.default_locale}/billing/checkout/new?plan_id=#{plan.id}")
  end
end
# rubocop:enable RSpec/NoExpectationExample
