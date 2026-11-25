# frozen_string_literal: true

# rubocop:disable Layout/LineLength

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_products_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_products_spec.rb.
RSpec.describe 'Documentation screenshots for products and prices', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let!(:product) do
    create(:better_together_billing_product, :fixed_term, name: 'Storage top-up', summary: 'Five gigabytes more room for a year.', listed: true,
                                                          description: 'Bought once, in any number, and lasts twelve months.')
  end
  let!(:price) { create(:better_together_billing_price, product:, amount_cents: 500, currency: 'USD') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    product.grants.create!(platform_id: host_platform.id, kind: 'quota_allowance',
                           parameters: { 'quota_type' => 'media_storage', 'amount' => 5_368_709_120 })
    host_platform.billing_processor_settings.find_or_create_by!(processor: 'cash') do |setting|
      setting.assign_attributes(enabled: true, acknowledge: true, settings: { 'instructions' => 'At the hall' })
    end
  end

  after { Current.platform = nil }

  def scroll_to(selector) = page.execute_script("document.querySelector('#{selector}').scrollIntoView({block: 'center'})")

  def capture(name, role:, title:, journey:, callouts:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name, device: :both,
            metadata: { locale: I18n.default_locale, role:, feature_set: 'billing_products', flow: name, source_spec: self.class.metadata[:file_path] },
            callouts: callouts.map { |id, selector, text| { id:, selector:, title: text.split(': ').first, bullets: [text] } },
            narrative: { title:, audience: [role == 'visitor' ? 'end_user' : 'platform_organizer'], journey_step: journey,
                         callouts: callouts.map { |id, _selector, text| { id:, title: text, description: text } },
                         accessibility_notes: 'Every field has a label; each section is labelled by its heading.' },
      &
    )
  end

  it 'captures the steward list of products' do
    capture('billing_products_index', role: 'platform_manager', title: 'Products', journey: 'As a steward I see what the platform sells once.',
                                      callouts: [['table', '#billing-products-table', 'Each product with its current price and how long it lasts']]) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/products"
      expect(page).to have_css('#billing-products-table')
      scroll_to('#billing-products-table')
    end
  end

  it 'captures a product with its prices and what it includes' do
    capture('billing_product_show', role: 'platform_manager', title: 'A product', journey: 'As a steward I read a product, its prices and what a buyer gets.',
                                    callouts: [['prices', "##{ActionView::RecordIdentifier.dom_id(product, :prices)}", 'Prices: add one, or take one off sale'],
                                               ['grants', "##{ActionView::RecordIdentifier.dom_id(product, :grants)}", 'What a buyer gets']]) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/products/#{product.id}"
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(product, :prices)}")
      scroll_to("##{ActionView::RecordIdentifier.dom_id(product, :prices)}")
    end
  end

  it 'captures the product form with its lifetime' do
    capture('billing_product_form', role: 'platform_manager', title: 'Product form', journey: 'As a steward I say how long what a product gives lasts.',
                                    callouts: [['lifetime', '#billing-product-lifetime', 'Until used, or for a set time after it is paid']]) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/products/#{product.id}/edit"
      expect(page).to have_css('#billing-product-lifetime')
      scroll_to('#billing-product-lifetime')
    end
  end

  it 'captures adding a price' do
    capture('billing_price_form', role: 'platform_manager', title: 'Add a price', journey: 'As a steward I add a price; the old one is taken off sale.',
                                  callouts: [['note', '#billing-price-immutable-note', 'A price never changes once it is added']]) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/products/#{product.id}/prices/new"
      expect(page).to have_css('#billing-price-immutable-note')
      scroll_to('#billing-price-form')
    end
  end

  it 'captures the product in the catalog' do
    capture('billing_catalog_product', role: 'visitor', title: 'Products in the catalog', journey: 'As a visitor I see a product and its price.',
                                       callouts: [['product', "##{ActionView::RecordIdentifier.dom_id(product, :catalog)}", 'Price and a button that starts checkout']]) do
      visit "/#{I18n.default_locale}/billing/catalog"
      expect(page).to have_css('#billing-catalog-products')
      scroll_to('#billing-catalog-products')
    end
  end

  it 'captures checkout choosing how many' do
    capture('billing_checkout_quantity', role: 'user', title: 'Checkout with a quantity', journey: 'As a buyer I choose how many and see the total.',
                                         callouts: [['quantity', '#billing-checkout-quantity-form', 'How many; the total follows'],
                                                    ['summary', '#billing-checkout-summary', 'The order']]) do
      capybara_login_as_user
      visit "/#{I18n.default_locale}/billing/checkout/new?price_id=#{price.id}&quantity=3"
      expect(page).to have_css('#billing-checkout-quantity-form')
      scroll_to('#billing-checkout-quantity-form')
    end
  end
end
# rubocop:enable Layout/LineLength
