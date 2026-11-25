# frozen_string_literal: true

require 'rails_helper'

# A steward adds a price to a product and takes one off sale; a price is never edited.
RSpec.describe BetterTogether::Billing::PricesController do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:product) { create(:better_together_billing_product) }

  def prices_path = better_together.billing_product_prices_path(product, locale:)

  it 'turns a member away' do
    sign_in buyer_user

    expect do
      post prices_path, params: { billing_price: { amount: '5', currency: 'USD' } }
    end.not_to(change(BetterTogether::Billing::Price, :count))
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'shows the form with the note that a price never changes' do
      get better_together.new_billing_product_price_path(product, locale:)

      expect(response.body).to include('billing-price-form', 'billing-price-immutable-note')
    end

    it 'adds a price from an amount typed in major units', :aggregate_failures do
      post prices_path, params: { billing_price: { amount: '7.50', currency: 'USD', label_en: 'Early bird' } }

      price = product.prices.sole
      expect(price).to have_attributes(amount_cents: 750, currency: 'USD', platform_id: host_platform.id, label: 'Early bird')
      expect(response).to redirect_to_billing_screen(better_together.billing_product_path(product, locale:))
    end

    it 'refuses an amount that is not a number, and shows the error' do
      post prices_path, params: { billing_price: { amount: 'lots', currency: 'USD' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(product.prices).to be_empty
    end

    it 'takes a price off sale, keeping it' do
      price = create(:better_together_billing_price, product:)
      patch better_together.archive_billing_product_price_path(product, price, locale:)

      expect(price.reload).to be_archived
      expect(product.current_price).to be_nil
    end

    it 'cannot add a price to another platform\'s product' do
      other = create(:better_together_billing_product, platform: create(:better_together_platform))

      post better_together.billing_product_prices_path(other, locale:), params: { billing_price: { amount: '5', currency: 'USD' } }

      expect(response).to have_http_status(:not_found)
    end
  end
end
