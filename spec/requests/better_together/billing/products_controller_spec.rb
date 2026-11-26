# frozen_string_literal: true

require 'rails_helper'

# Stewards manage what the platform sells once: the products, their prices and what each includes.
RSpec.describe BetterTogether::Billing::ProductsController do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:product) { create(:better_together_billing_product, name: 'Storage top-up') }

  def products_path = better_together.billing_products_path(locale:)
  def product_path(record = product) = better_together.billing_product_path(record, locale:)
  def product_params(**overrides) = { billing_product: { identifier: 'top_up', name_en: 'Top-up', lifetime: 'until_used', **overrides } }

  it 'sends a visitor to sign in' do
    get products_path

    expect(response).to have_http_status(:found)
  end

  it 'turns a member away' do
    sign_in buyer_user

    expect { post products_path, params: product_params }.not_to(change { host_platform.billing_products.count })
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'lists the products with their current price' do
      create(:better_together_billing_price, product:, amount_cents: 750, currency: 'USD')
      get products_path

      expect(response).to have_http_status(:ok)
      expect_html_contents('Storage top-up', 'US$7.50')
      expect(response.body).to include('billing-products-table', ActionView::RecordIdentifier.dom_id(product), 'new-billing-product-btn')
    end

    it 'creates a product, as a standard one, on this platform', :aggregate_failures do
      expect { post products_path, params: product_params }.to change { host_platform.billing_products.count }.by(1)

      created = host_platform.billing_products.find_by(identifier: 'top_up')
      expect(response).to redirect_to_billing_screen(product_path(created))
      expect(created).to have_attributes(type: 'BetterTogether::Billing::Product', seller_id: nil, lifetime: 'until_used')
    end

    it 'does not let a request choose the subtype, the platform or the seller', :aggregate_failures do
      other = create(:better_together_platform)
      post products_path, params: product_params(type: 'Evil', platform_id: other.id, seller_type: 'BetterTogether::Person')

      created = host_platform.billing_products.find_by(identifier: 'top_up')
      expect(created).to have_attributes(type: 'BetterTogether::Billing::Product', platform_id: host_platform.id, seller_id: nil)
    end

    it 'refuses a fixed term without its length, and shows the error' do
      post products_path, params: product_params(lifetime: 'fixed_term')

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('billing-product-errors')
    end

    it 'saves a fixed term, and changes a product' do
      patch product_path, params: { billing_product: { lifetime: 'fixed_term', term_length: 6, term_unit: 'month', name_en: 'Bigger top-up' } }

      expect(product.reload).to have_attributes(lifetime: 'fixed_term', term_length: 6, term_unit: 'month', name: 'Bigger top-up')
    end

    it 'shows the product with its prices and what it includes', :aggregate_failures do
      create(:better_together_billing_price, product:, amount_cents: 750, currency: 'USD')
      get product_path

      ids = %i[prices grants].map { |part| ActionView::RecordIdentifier.dom_id(product, part) }
      expect(response.body).to include(*ids,
                                       'new-billing-price-btn', 'billing-grant-storage-form')
    end

    it 'adds a quota grant and brings the buyers up to date' do
      expect do
        post "#{product_path}/grants", params: { kind: 'quota_allowance', quota_type: 'media_storage', amount: '1000000000' }
      end.to change { product.grants.count }.by(1)

      expect(BetterTogether::Billing::SyncPlanEntitlementsJob).to have_been_enqueued.with(product)
    end

    it 'removes a grant' do
      grant = product.grants.create!(platform_id: product.platform_id, kind: 'quota_allowance',
                                     parameters: { 'quota_type' => 'media_storage', 'amount' => 1000 })

      expect { delete "#{product_path}/grants/#{grant.id}" }.to change { product.grants.count }.by(-1)
    end

    it 'cannot reach another platform\'s product' do
      other = create(:better_together_billing_product, platform: create(:better_together_platform))

      get product_path(other)

      expect(response).to have_http_status(:not_found)
    end
  end
end
