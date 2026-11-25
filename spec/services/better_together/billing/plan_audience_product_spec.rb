# frozen_string_literal: true

require 'rails_helper'

# The people a change to what a product includes reaches: those whose paid order has a line for one of its prices.
RSpec.describe BetterTogether::Billing::PlanAudience do # rubocop:disable RSpec/SpecFilePathFormat
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:product) { create(:better_together_billing_product) }
  let(:price) { create(:better_together_billing_price, product:, amount_cents: 500, currency: 'USD') }

  it 'counts buyers of any of its prices, and no subscribers', :aggregate_failures do
    order = place_order(purpose: 'one_time', payment_method: 'cash', line_items: [{ purchasable: price }])
    pay_manually(order)

    audience = described_class.new(product)
    expect(audience.terms).to be_empty
    expect(audience.paid_orders).to contain_exactly(order.reload)
    expect(audience.count).to eq(1)
  end

  it 'does not count an order that is not paid' do
    place_order(purpose: 'one_time', payment_method: 'cash', line_items: [{ purchasable: price }])

    expect(described_class.new(product).count).to eq(0)
  end
end
