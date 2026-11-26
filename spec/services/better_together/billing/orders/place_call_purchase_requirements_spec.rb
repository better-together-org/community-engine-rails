# frozen_string_literal: true

require 'rails_helper'

# The server refuses an order for a purchasable whose requirements the buyer does not meet, whatever the screens did.
RSpec.describe BetterTogether::Billing::Orders::Place, '#call' do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'
  include_context 'with billing extras'

  let(:cash) { { processor: nil, processor_price_id: nil, processor_product_id: nil, accepted_payment_methods: %w[cash] } }
  let(:plan) { create(:better_together_billing_plan, **cash, amount_cents: 2000) }
  let(:extra) { create_extra(amount_cents: 700, needs: :any_plan) }

  def place(*purchasables, **)
    purchasables = purchasables.map { |item| item.is_a?(BetterTogether::Billing::Product) ? item.current_price : item }
    place_order(purpose: purchasables.any? { |item| item.plan_line? && item.renews? } ? 'subscription' : 'one_time',
                payment_method: 'cash', line_items: purchasables.map { |purchasable| { purchasable: } }, **)
  end

  it 'refuses an add-on bought alone by someone who holds no plan' do
    expect { place(extra) }.to raise_error(described_class::Refused, /Needs/)
  end

  it 'allows the add-on with a plan in the same order, or after holding the plan' do
    expect(place(plan, extra)).to be_awaiting_payment
    hold_plan!(plan)

    expect(place(extra)).to be_awaiting_payment
  end

  it 'applies a stored rule on a specific plan, and on a product that needs another product' do
    other = create_extra(amount_cents: 400, needs: create(:better_together_billing_plan, **cash), name: 'Needy')

    expect { place(other) }.to raise_error(described_class::Refused, /Needs/)
  end
end
