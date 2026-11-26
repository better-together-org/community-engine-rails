# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_buyer_refunds_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_buyer_refunds_spec.rb.
RSpec.describe 'Documentation screenshots for refunds seen by the buyer', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:buyer_user) { find_or_create_test_user('user@example.test') }
  let(:order) { place_offline('cash') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    payment = offline_for(order).payment
    transition.receive(offline_for(order), by: steward)
    BetterTogether::Billing::Refunds::Record.call(payment: payment.reload, amount_cents: 1250, idempotency_key: 'one',
                                                  reason: 'requested_by_buyer', recorded_by: steward)
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'buyer', feature_set: 'billing_refunds', flow:, source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the refunds on the buyer\'s order' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_buyer_refunds_order',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_buyer_refunds_order'),
      callouts: [{ id: 'refunds', selector: '#billing-order-refunds', title: 'Money given back',
                   avoid_container_selector: 'main',
                   bullets: ['Each refund with its date, status and amount, and the total refunded.'] }]
    ) do
      capybara_login_as_user
      visit "/#{I18n.default_locale}/billing/orders/#{order.id}"
      scroll_to(find('#billing-order-refunds'), align: :center)
      expect(page).to have_css('#billing-order-refunds-table')
    end
  end

  it 'captures the refunded amount on the billing page' do
    target = "##{ActionView::RecordIdentifier.dom_id(order, :hub_refunded)}"

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_buyer_refunds_hub',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_buyer_refunds_hub'),
      callouts: [{ id: 'refunded', selector: target, title: 'Refunded amount',
                   bullets: ['An order that has had money given back says how much, beside its status.'] }]
    ) do
      capybara_login_as_user
      visit "/#{I18n.default_locale}/billing"
      scroll_to(find(target), align: :center)
      expect(page).to have_css(target)
    end
  end
end
