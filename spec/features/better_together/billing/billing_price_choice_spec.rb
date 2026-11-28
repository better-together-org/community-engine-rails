# frozen_string_literal: true

require 'rails_helper'

# In a real browser: a plan sold monthly and yearly shows both prices, and the buyer reaches checkout for the one they pick.
RSpec.describe 'Billing price choice', :js, :no_auth, :skip_host_setup, retry: 0 do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let!(:plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'month',
                                                     name: 'Choice supporter', currency: 'USD', amount_cents: 1000, listed: true)
  end
  let!(:annual) do
    create(:better_together_billing_price, product: plan, platform: plan.platform, kind: 'recurring', interval: 'year',
                                           amount_cents: 10_000, currency: 'USD')
  end

  before do
    Current.platform = host_platform
    host_platform.billing_processor_settings.find_or_create_by!(processor: 'cash') do |setting|
      setting.assign_attributes(enabled: true, acknowledge: true, settings: { 'instructions' => 'At the hall' })
    end
  end

  after { Current.platform = nil }

  it 'lets a signed-in buyer pick the yearly price and carries it into checkout', :aggregate_failures do
    find_or_create_test_user('user@example.test')
    capybara_login_as_user
    visit "/#{locale}/billing/catalog/#{plan.id}"
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(plan, :catalog_prices)}", wait: 10)
    expect(page).to be_axe_clean.within('main').according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa).skipping('region')

    find("##{ActionView::RecordIdentifier.dom_id(annual, :catalog_option_buy)}").click

    expect(page).to have_current_path(%r{/billing/checkout/new\?.*price_id=#{annual.id}}, wait: 10)
    expect(page).to have_content('$100.00')
  end
end
