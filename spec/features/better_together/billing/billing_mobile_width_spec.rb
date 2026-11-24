# frozen_string_literal: true

require 'rails_helper'

# The buyer and steward billing screens at phone width: nothing scrolls sideways and no axe violations.
RSpec.describe 'Billing at phone width', :js, :no_auth, :skip_host_setup, retry: 0 do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:phone) { [390, 844] }
  let(:desktop) { [1400, 1400] }
  let(:locale) { I18n.default_locale }
  let!(:buyer_user) { find_or_create_test_user('user@example.test') }
  let(:buyer) { buyer_user.person }
  let(:wcag) { %i[wcag2a wcag2aa wcag21a wcag21aa] }
  let!(:listed_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'month',
                                                     name: 'Phone plan', currency: 'USD', amount_cents: 1500, listed: true)
  end
  let!(:term) { start_subscription }
  let(:order) { term.periods.first.order }

  before do
    Current.platform = host_platform
    purchase_agreements_for(host_platform)
    page.driver.browser.manage.window.resize_to(*phone)
  end

  after do
    page.driver.browser.manage.window.resize_to(*desktop)
    Current.platform = nil
  end

  # Elements that stick out past the right edge of the screen, outside anything that scrolls on its own.
  OFFENDERS_JS = <<~JS # rubocop:disable RSpec/LeakyConstantDeclaration, Lint/ConstantDefinitionInBlock
    Array.from(document.querySelectorAll('body *')).filter(function (el) {
      return el.getBoundingClientRect().right > window.innerWidth + 1 && !el.closest('table');
    }).slice(0, 6).map(function (el) { return el.tagName.toLowerCase() + '#' + el.id + '.' + el.className + '@' + Math.round(el.getBoundingClientRect().right); });
  JS

  def expect_fits_phone(path) # rubocop:disable Metrics/AbcSize
    visit "/#{locale}#{path}"
    expect(page).to have_css('main', wait: 10)
    overflow = page.evaluate_script('document.documentElement.scrollWidth - window.innerWidth')
    expect(overflow).to be <= 1, -> { "#{path} scrolls sideways by #{overflow}px: #{page.evaluate_script(OFFENDERS_JS).inspect}" }
    expect(page).to be_axe_clean.within('main').according_to(*wcag).skipping('region')
  end

  it 'fits the buyer screens', :aggregate_failures do
    capybara_login_as_user

    ['/billing/catalog', "/billing/catalog/#{listed_plan.id}", '/billing', '/billing/subscriptions', "/billing/subscriptions/#{term.id}",
     '/billing/orders', "/billing/orders/#{order.id}", "/billing/checkout/new?plan_id=#{listed_plan.id}&payment_method=cash"].each do |path|
      expect_fits_phone(path)
    end
  end

  it 'fits the steward screens', :aggregate_failures do
    capybara_login_as_platform_manager

    ['/billing/plans', '/billing/sales', "/billing/sales/#{order.id}", '/billing/subscribers', '/billing/processor_settings',
     '/billing/agreement_requirements'].each { |path| expect_fits_phone(path) }
  end

  it 'lets a buyer reach the subscribe button and the method choice with a thumb', :aggregate_failures do
    capybara_login_as_user
    visit "/#{locale}/billing/catalog"
    click_link 'Subscribe Phone plan'

    expect(page).to have_css('#billing-checkout-method-cash', wait: 10)
    find('#billing-checkout-method-cash').click
    expect(page).to have_button('billing-checkout-continue-btn')
  end
end
