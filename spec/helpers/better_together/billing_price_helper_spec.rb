# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BillingPriceHelper do
  before { helper.extend(BetterTogether::BillingHelper) }

  def price(**attrs) = build(:better_together_billing_price, currency: 'CAD', amount_cents: 1000, **attrs)

  it 'says a one-time price is paid once' do
    expect(helper.billing_price_terms(price)).to eq('CA$10.00 once')
  end

  it 'says how often a recurring price renews' do
    expect(helper.billing_price_terms(price(kind: 'recurring', interval: 'month'))).to eq('CA$10.00 a month')
    expect(helper.billing_price_terms(price(kind: 'recurring', interval: 'year'))).to eq('CA$10.00 a year')
    expect(helper.billing_price_terms(price(kind: 'recurring', interval: 'month', interval_count: 3))).to eq('CA$10.00 every 3 months')
  end
end
