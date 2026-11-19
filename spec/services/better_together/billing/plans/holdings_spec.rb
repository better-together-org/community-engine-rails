# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Plans::Holdings do
  include_context 'with subscription fixtures'

  let(:attrs) { { platform: host_platform, processor: nil, accepted_payment_methods: %w[cash], currency: 'USD' } }
  let(:one_time) { create(:better_together_billing_plan, :unlinked, :one_time, **attrs) }

  def held = described_class.call(platform: host_platform, person: buyer)

  it 'holds nothing for a visitor or someone with no plan' do
    expect(described_class.call(platform: host_platform, person: nil)).to eq([])
    expect(held).to eq([])
  end

  it 'holds the plan of a live subscription' do
    start_subscription

    expect(held).to include(sub_plan.id)
  end

  it 'holds a plan bought once while the order stands, and stops when it is refunded' do
    order = place_order(buyer:, purpose: 'one_time', line_items: [{ purchasable: one_time }], payment_method: 'cash')
    order.update!(status: 'paid', paid_at: Time.current)
    expect(held).to eq([one_time.id])

    order.update!(status: 'refunded')
    expect(held).to eq([])
  end

  it 'never holds an add-on' do
    add_on = create(:better_together_billing_plan, :unlinked, :one_time, **attrs, add_on: true)
    order = place_order(buyer:, purpose: 'one_time', line_items: [{ purchasable: add_on }], payment_method: 'cash')
    order.update!(status: 'paid', paid_at: Time.current)

    expect(held).to eq([])
  end
end
