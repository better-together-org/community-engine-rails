# frozen_string_literal: true

require 'rails_helper'

# A product is found in the catalog and bought by its price, in a number, through the same checkout as a plan.
RSpec.describe 'Buying a product', :request do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:member) { find_or_create_test_user("product-buyer-#{SecureRandom.hex(4)}@example.test", password) }
  let(:buyer) { member.person }
  let(:buyer_address) { create_billing_address_for(buyer) }
  let(:product) { create(:better_together_billing_product, name: 'Storage top-up', listed: true, summary: 'More room for your files') }
  let!(:price) { create(:better_together_billing_price, product:, amount_cents: 500, currency: 'USD') }

  def enable_cash
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
  end

  def ticks
    BetterTogether::Agreement.all.to_h { |a| [BetterTogether::ApplicationController.helpers.agreement_acceptance_param_name(a), '1'] }
  end

  describe 'the catalog' do
    it 'lists a listed product with its price and a way to buy it, to a visitor' do
      get better_together.billing_catalog_path(locale:)

      expect_html_contents('Storage top-up', 'US$5.00', 'More room for your files')
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(product, :catalog),
                                       better_together.new_billing_checkout_path(price_id: price.id, locale:))
    end

    it 'leaves out a product that is not listed or has no price on sale', :aggregate_failures do
      product.update!(listed: false)
      other = create(:better_together_billing_product, name: 'Unpriced', listed: true)

      get better_together.billing_catalog_path(locale:)

      expect_no_html_content('Storage top-up')
      expect_no_html_content(other.name)
    end

    it 'shows the product page, and a 404 for a product that is not listed', :aggregate_failures do
      get better_together.billing_catalog_product_path(product, locale:)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(product, :buy))

      product.update!(listed: false)
      get better_together.billing_catalog_product_path(product, locale:)
      expect(response).to have_http_status(:not_found)
    end

    it 'shows no product that is limited to members to a visitor' do
      product.update!(restricted_to_members: true)

      get better_together.billing_catalog_path(locale:)

      expect_no_html_content('Storage top-up')
    end
  end

  context 'when signed in' do
    before do
      enable_cash
      BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform).each_value { |agreement| agreement.update!(lifecycle_state: 'active') }
      sign_in member
    end

    it 'shows the product, its quantity and how to pay', :aggregate_failures do
      get better_together.new_billing_checkout_path(price_id: price.id, quantity: 3, locale:)

      expect(response).to have_http_status(:ok)
      expect_html_contents('Storage top-up', 'US$15.00')
      expect(response.body).to include('billing-checkout-quantity-form', 'billing-checkout-method-cash')
      expect(response.body).not_to include('billing-checkout-add-ons-form')
    end

    it 'is a 404 for a price that is off sale' do
      price.archive!

      get better_together.new_billing_checkout_path(price_id: price.id, locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'places an order for the number chosen, as a one-time purchase', :aggregate_failures do
      post better_together.billing_checkout_path(locale:),
           params: { price_id: price.id, quantity: 2, payment_method: 'cash', **billing_address_params(buyer_address) }.merge(ticks)

      order = host_platform.billing_orders.order(:created_at).last
      expect(response).to redirect_to_billing_screen(better_together.billing_order_path(order, locale:))
      expect(order).to have_attributes(purpose: 'one_time', currency: 'USD')
      expect(order.line_items.sole).to have_attributes(purchasable: price, quantity: 2)
      expect(order.total_cents).to eq(1000)
    end

    it 'keeps the number within limits' do
      get better_together.new_billing_checkout_path(price_id: price.id, quantity: 5000, locale:)

      expect(response.body).to include(%(value="#{BetterTogether::Billing::CheckoutsController::MAX_QUANTITY}"))
    end

    it 'does not sell a product limited to members to someone who is not one' do
      product.update!(restricted_to_members: true)

      get better_together.new_billing_checkout_path(price_id: price.id, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end
end
