# frozen_string_literal: true

require 'rails_helper'

# A plan that costs nothing: it needs no way to pay, an order for it is paid on placing, and what it includes is given
# with no payment to wait for. One-time and recurring plans alike.
RSpec.describe 'Free plans' do # rubocop:disable RSpec/DescribeClass
  include_context 'with entitlement fixtures'

  let(:free_attrs) do
    { processor: nil, processor_price_id: nil, processor_product_id: nil, amount_cents: 0, currency: 'USD', accepted_payment_methods: [] }
  end
  let(:free_once) { create(:better_together_billing_plan, :one_time, **free_attrs) }
  let(:free_monthly) { create(:better_together_billing_plan, billing_interval: 'month', **free_attrs) }
  let(:place_free) do
    lambda { |plan, purpose|
      place_order(purpose:, line_items: [{ purchasable: plan }])
    }
  end

  it 'is a valid plan with no processor and no way of paying' do
    plan = build(:better_together_billing_plan, :one_time, **free_attrs, platform: host_platform)

    expect(plan).to be_valid
  end

  it 'still needs a way of paying when it costs something' do
    plan = build(:better_together_billing_plan, :one_time, **free_attrs, amount_cents: 100, platform: host_platform)

    expect(plan).not_to be_valid
  end

  it 'is placed with no payment method and paid at once, with nothing opened to pay' do
    order = place_free.call(free_once, 'one_time')

    expect(order).to be_paid
    expect(order.payments).to be_empty
    expect(order.offline_payments).to be_empty
  end

  it 'gives a one-time plan its entitlement and membership grant when placed' do
    add_grant('membership_role', { 'joinable' => 'platform', 'role' => supporter_role.identifier }, plan: free_once)
    order = place_free.call(free_once, 'one_time')
    follow_up

    expect(host_platform.billing_entitlements.find_by(order_id: order.id)).to have_attributes(status: 'active', beneficiary: buyer)
    expect(platform_membership(buyer)).to have_attributes(status: 'active')
  end

  it 'starts a subscription for a recurring plan, with its entitlement, and renews it for nothing' do
    add_grant('membership_role', { 'joinable' => 'platform', 'role' => supporter_role.identifier }, plan: free_monthly)
    order = place_free.call(free_monthly, 'subscription')
    follow_up
    term = order.reload.subject

    expect(term).to be_present
    expect(entitlement_for(term)).to have_attributes(status: 'active', beneficiary: buyer, plan: free_monthly)
    expect(platform_membership(buyer)).to have_attributes(status: 'active')

    renewal = generate_renewal(term, at: start_time + 1.month)
    expect(renewal.order).to have_attributes(total_cents: 0, status: 'paid')
  end

  it 'offers no payment methods to choose from' do
    expect(BetterTogether::Billing::Checkout::Methods.call(platform: host_platform, plan: free_once, buyer:)).to be_empty
  end
end
