# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the product screens: the steward's list, form, page and price form, the catalog entries and the
# quantity step of checkout. Documentation screenshots and tooling target these identifiers.
RSpec.describe 'Billing products DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let!(:product) { create(:better_together_billing_product, :fixed_term, listed: true, summary: 'More room') }
  let!(:price) { create(:better_together_billing_price, product:, amount_cents: 500, currency: 'USD') }

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  def dom_id(*) = ActionView::RecordIdentifier.dom_id(*)

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'exposes the list, a row and its actions' do
      get "/#{locale}/billing/products"

      expect_ids('billing-products-index-page', 'billing-products-table', 'new-billing-product-btn', dom_id(product), dom_id(product, :actions))
    end

    it 'exposes the form fields' do
      get "/#{locale}/billing/products/new"

      expect_ids('billing-product-form', 'billing-product-core-fields', 'billing-product-lifetime', 'billing-product-term-length',
                 'billing-product-term-unit', 'billing-product-tax-category', 'billing-product-listing', 'billing-product-submit')
    end

    it 'exposes the product page, its prices and what it includes' do
      get "/#{locale}/billing/products/#{product.id}"

      expect_ids(dom_id(product, :show_page), dom_id(product, :summary_card), dom_id(product, :summary_details), dom_id(product, :lifetime),
                 dom_id(product, :prices), dom_id(product, :prices_list), 'new-billing-price-btn', dom_id(price), dom_id(price, :archive_btn),
                 dom_id(product, :grants), 'billing-grant-storage-form')
    end

    it 'exposes the price form' do
      get "/#{locale}/billing/products/#{product.id}/prices/new"

      expect_ids('billing-price-new-page', 'billing-price-form', 'billing-price-immutable-note', 'billing-price-label-fields',
                 'billing-price-submit')
    end
  end

  it 'exposes a catalog card, its price and buy button, and the product page' do
    get "/#{locale}/billing/catalog"
    expect_ids('billing-catalog-products', dom_id(product, :catalog), dom_id(product, :catalog_link), dom_id(product, :catalog_price),
               dom_id(product, :buy))

    get "/#{locale}/billing/catalog/products/#{product.id}"
    expect_ids('billing-catalog-product-page', dom_id(product, :catalog_price), dom_id(product, :catalog_lifetime), dom_id(product, :buy))
  end
end
