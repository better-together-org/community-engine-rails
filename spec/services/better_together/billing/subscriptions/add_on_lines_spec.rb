# frozen_string_literal: true

require 'rails_helper'

# An order for a primary plan plus add-ons: the plan drives the subscription, the extras only add to the total.
RSpec.describe BetterTogether::Billing::Subscriptions::Start do # rubocop:disable RSpec/SpecFilePathFormat
  include_context 'with orders fixtures'

  let(:attrs) { { platform: host_platform, processor: nil, accepted_payment_methods: %w[cash], currency: 'USD' } }
  let(:plan) { create(:better_together_billing_plan, :unlinked, **attrs, billing_interval: 'month', amount_cents: 2000) }
  let(:add_on) { create(:better_together_billing_plan, :unlinked, :one_time, **attrs, amount_cents: 500, add_on: true) }
  let(:order) { place_order(purpose: 'subscription', line_items: [{ purchasable: plan }, { purchasable: add_on }]) }

  it 'finds the primary plan among the lines' do
    expect(described_class.plan_line(order).purchasable).to eq(plan)
  end

  it 'prices the term from the plan line alone' do
    expect(described_class.plan_line(order).unit_amount_cents).to eq(2000)
    expect(order.total_cents).to eq(2500)
  end
end
