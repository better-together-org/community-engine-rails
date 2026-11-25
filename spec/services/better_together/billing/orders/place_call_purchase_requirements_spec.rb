# frozen_string_literal: true

require 'rails_helper'

# The server refuses an order for a purchasable whose requirements the buyer does not meet, whatever the screens did.
RSpec.describe BetterTogether::Billing::Orders::Place, '#call' do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:cash) { { processor: nil, processor_price_id: nil, processor_product_id: nil, accepted_payment_methods: %w[cash] } }
  let(:plan) { create(:better_together_billing_plan, :one_time, **cash, amount_cents: 2000) }
  let(:extra) { create(:better_together_billing_plan, :one_time, **cash, amount_cents: 700, add_on: true) }

  def place(*purchasables, **)
    place_order(purpose: 'one_time', payment_method: 'cash', line_items: purchasables.map { |purchasable| { purchasable: } }, **)
  end

  it 'refuses an add-on bought alone by someone who holds no plan' do
    expect { place(extra) }.to raise_error(described_class::Refused, /Needs/)
  end

  it 'allows the add-on with a plan in the same order, or after holding the plan' do
    expect(place(plan, extra)).to be_awaiting_payment
    pay_manually(place(plan))

    expect(place(extra)).to be_awaiting_payment
  end

  it 'applies a stored rule on a plan too' do
    create(:better_together_billing_purchase_requirement, dependent: plan,
                                                          prerequisite: create(:better_together_billing_plan, :one_time, **cash))

    expect { place(plan) }.to raise_error(described_class::Refused, /Needs/)
  end
end
