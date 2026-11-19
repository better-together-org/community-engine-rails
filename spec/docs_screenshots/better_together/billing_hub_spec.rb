# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_hub_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_hub_spec.rb.
RSpec.describe 'Documentation screenshots for the buyer billing page', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    start_subscription(payer: member_person)
    BetterTogether::Billing::Credit::Grant.call(platform: host_platform, holder: member_person, amount_cents: 1500, currency: 'USD',
                                                origin: 'steward_grant', actor: steward, idempotency_key: 'hub-shot')
  end

  after { Current.platform = nil }

  def member_person = find_or_create_test_user('user@example.test', 'SecureTest123!@#').person

  it 'captures the billing page a member finds in their account menu' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_hub',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'user', feature_set: 'billing_hub', flow: 'billing_hub',
                  source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'plans', selector: '#billing-hub-plans', title: 'Active plans',
                   bullets: ['Each plan with its renewal date and price; open one to cancel or resume it.'] },
                 { id: 'orders', selector: '#billing-hub-orders', title: 'Recent orders',
                   bullets: ['The latest orders with their status; all orders and receipts are one link away.'] }],
      narrative: {
        title: 'My billing',
        audience: %w[end_user],
        journey_step: 'As a member, I open Billing from my account menu and see my plans, orders, credit and access in one place.',
        callouts: [{ id: 'plans', title: 'Plans', description: 'Active plans and when they renew.' }],
        accessibility_notes: 'Each area is a labelled section with its own heading and a text link.'
      }
    ) do
      capybara_login_as_user
      visit "/#{I18n.default_locale}/billing"
      expect(page).to have_css('#billing-hub-plans')
      page.execute_script("document.querySelector('#billing-hub-plans').scrollIntoView({block: 'start'})")
    end
  end

  it 'captures the order list, paged' do
    stub_const('BetterTogether::Billing::OrdersController::PER_PAGE', 2)
    plan = create(:better_together_billing_plan, :one_time, processor: nil, processor_price_id: nil, processor_product_id: nil,
                                                            amount_cents: 0, accepted_payment_methods: [])
    3.times { |i| travel_to((i + 1).hours.ago) { place_order(buyer: member_person, line_items: [{ purchasable: plan }]) } }

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_orders_paged',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'user', feature_set: 'billing_hub', flow: 'billing_orders_paged',
                  source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'pages', selector: '#billing-orders-pagination', title: 'More orders',
                   bullets: ['Orders are listed newest first, a page at a time.'] }],
      narrative: {
        title: 'My orders',
        audience: %w[end_user],
        journey_step: 'As a member, I page through all my orders.',
        callouts: [{ id: 'pages', title: 'Pages', description: 'Older orders are on the next page.' }],
        accessibility_notes: 'The page links are a labelled navigation.'
      }
    ) do
      capybara_login_as_user
      visit "/#{I18n.default_locale}/billing/orders"
      expect(page).to have_css('#billing-orders-pagination')
      page.execute_script("document.querySelector('#billing-orders-pagination').scrollIntoView({block: 'center'})")
    end
  end
end
