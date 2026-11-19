# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_partial_payments_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_partial_payments_spec.rb.
RSpec.describe 'Documentation screenshots for billing partial payments', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:password) { 'SecureTest123!@#' }
  let(:buyer_user) { find_or_create_test_user("part-buyer-#{SecureRandom.hex(4)}@example.test", password) }
  let(:buyer) { buyer_user.person }

  let(:order) do
    give_credit(1000, holder: buyer)
    place_order(payment_method: nil,
                payments: [{ payment_method: 'store_credit', amount_cents: 1000 },
                           { payment_method: 'cash', amount_cents: 1500 }])
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    host_platform.billing_processor_settings.find_or_create_by!(processor: 'cash') do |setting|
      setting.assign_attributes(enabled: true, acknowledge: true, settings: { 'instructions' => 'At the hall' })
    end
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:, role:)
    { locale: I18n.default_locale, role:, feature_set: 'billing_partial_payments', flow:, source_spec: self.class.metadata[:file_path] }
  end

  it 'captures a part-paid order with its add-payment form' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_order_part_paid',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_order_part_paid', role: 'user'),
      callouts: [{ id: 'add', selector: '#billing-order-add-payment-btn', title: 'Add a payment',
                   bullets: ['Pay the rest, or part of it, by any way of paying that is open, store credit included.'] }],
      narrative: {
        title: 'A part-paid order',
        audience: %w[end_user],
        journey_step: 'As a buyer, I pay part of an order now and the rest another way, whenever I am ready.',
        callouts: [{ id: 'add', title: 'Add a payment', description: 'Leave the amount empty to pay the rest.' }],
        accessibility_notes: 'Every field has a visible label; the amount hint is read with the field.'
      }
    ) do
      capybara_sign_in_user(buyer_user.email, password)
      visit "/#{I18n.default_locale}/billing/orders/#{order.id}"
      expect(page).to have_css('#billing-order-add-payment-form')
      scroll_to(find('#billing-order-add-payment-form'), align: :center)
    end
  end

  it 'captures the steward\'s panel for returning the parts of an order and cancelling it' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_sale_return_payments',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_sale_return_payments', role: 'platform_manager'),
      callouts: [{ id: 'return', selector: '#billing-sale-return-credit-btn', title: 'Return payments',
                   bullets: ['Each paid part, and how it goes back: credit with one click, cash by the seller, a card at the processor.'] }],
      narrative: {
        title: 'Return payments',
        audience: %w[platform_organizer],
        journey_step: 'As a platform organizer, I give back what was paid toward an order that will not be completed, then cancel it.',
        callouts: [{ id: 'return', title: 'Return payments', description: 'The order can be cancelled once nothing is held against it.' }],
        accessibility_notes: 'The list names each way of paying in text.'
      }
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/sales/#{order.id}"
      scroll_to(find("##{ActionView::RecordIdentifier.dom_id(order, :return_payments)}"), align: :center)
      expect(page).to have_css('#billing-sale-return-parts')
    end
  end
end
