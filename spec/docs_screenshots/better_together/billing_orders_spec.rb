# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_orders_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_orders_spec.rb.
RSpec.describe 'Documentation screenshots for billing orders', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:buyer) { create(:better_together_person) }
  let!(:order) { place_order(lines: [{ purchasable: plan, quantity: 1 }]) }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 1500, idempotency_key: 'part')
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_orders', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def visit_page(path)
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/#{path}"
  end

  it 'captures the steward\'s list of sales' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_sales_index',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_sales_index'),
      callouts: [{ id: 'sales', selector: '#billing-sales-table', title: 'Sales',
                   bullets: ['Every order for what this platform sells, with the buyer and where it stands.'] }],
      narrative: {
        title: 'Sales',
        audience: %w[platform_organizer],
        journey_step: 'As a platform organizer, I see what has been ordered and what is still waiting to be paid.',
        callouts: [{ id: 'sales', title: 'Status',
                     description: 'An order waits for payment until it is paid, cancelled or its hold runs out.' }],
        accessibility_notes: 'The table has column headers; status is text as well as colour.'
      }
    ) do
      visit_page('sales')
      expect(page).to have_css('#billing-sales-table')
    end
  end

  it 'captures one sale with its lines and payments' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_sale_show',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_sale_show'),
      callouts: [{ id: 'lines', selector: '#billing-order-lines', title: 'What was ordered',
                   bullets: ['Price and name as they were when the order was placed.'] },
                 { id: 'payments', selector: '#billing-order-payments', title: 'Payments',
                   bullets: ['An order can be paid in parts, by different methods.'] }]
    ) do
      visit_page("sales/#{order.id}")
      expect(page).to have_css('#billing-order-payments')
    end
  end

  it 'captures a buyer\'s own order' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_order_show',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_order_show'),
      callouts: [{ id: 'status', selector: '.billing-order-status-badge', title: 'Status', bullets: ['Where the order stands.'] }]
    ) do
      visit_page("orders/#{order.id}")
      expect(page).to have_css('.billing-order-status-badge')
    end
  end
end
