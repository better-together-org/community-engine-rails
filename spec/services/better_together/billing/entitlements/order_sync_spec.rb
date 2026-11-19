# frozen_string_literal: true

require 'rails_helper'

# A one-time plan: given when the order is paid, taken away if it is refunded.
RSpec.describe BetterTogether::Billing::Entitlements::Sync, 'for a paid order' do # rubocop:disable RSpec/SpecFilePathFormat, RSpec/DescribeMethod
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:once_plan) do
    create(:better_together_billing_plan, :one_time, processor: nil, processor_price_id: nil, processor_product_id: nil, amount_cents: 2000,
                                                     accepted_payment_methods: %w[cash])
  end
  let(:order) do
    travel_to(start_time) do
      add_grant('feature_access', { 'feature_key' => 'device_permissions', 'access_level' => 'beta' }, plan: once_plan)
      add_grant('quota_allowance', { 'quota_type' => 'media_storage', 'amount' => 700 }, plan: once_plan)
      placed = place_order(purpose: 'one_time', payment_method: 'cash', line_items: [{ purchasable: once_plan }])
      pay_manually(placed)
      follow_up
      placed.reload
    end
  end
  let(:entitlement) { host_platform.billing_entitlements.find_by(order_id: order.id) }

  it 'gives what the plan includes when the order is paid, with no end date' do
    expect(entitlement).to have_attributes(status: 'active', beneficiary: buyer, ends_at: nil, pay_subscription_id: nil)
    expect(entitlement.grants.applied.pluck(:kind)).to contain_exactly('feature_access', 'quota_allowance')
    expect(BetterTogether::Quotas::Allowances.extra_for(buyer, 'media_storage')).to eq(700)
  end

  it 'takes it away when the order is refunded, and gives it back if the refund fails' do
    entitlement
    refund = BetterTogether::Billing::Refunds::Record.call(payment: order.payments.sole, amount_cents: 2000, idempotency_key: 'r1')
    follow_up
    expect(entitlement.reload.status).to eq('revoked')
    expect(entitlement.grants.applied).to be_empty
    expect(BetterTogether::Quotas::Allowances.extra_for(buyer, 'media_storage')).to eq(0)

    refund.update!(status: 'failed')
    BetterTogether::Billing::Refunds::Resolve.call(refund, status: 'failed') if BetterTogether::Billing::Refunds::Resolve.respond_to?(:call)
    order.reload
    BetterTogether::Billing::Orders::Settle.call(order)
    follow_up

    expect(entitlement.reload.status).to eq('active')
  end

  it 'leaves it alone for a part refund' do
    entitlement
    BetterTogether::Billing::Refunds::Record.call(payment: order.payments.sole, amount_cents: 500, idempotency_key: 'r2')
    follow_up

    expect(entitlement.reload.status).to eq('active')
  end

  it 'gives it to who the order was placed for, not the buyer, when someone else is named' do
    other = create(:better_together_person)
    paid_for = travel_to(start_time) do
      add_grant('feature_access', { 'feature_key' => 'device_permissions', 'access_level' => 'beta' }, plan: once_plan)
      placed = place_order(purpose: 'one_time', payment_method: 'cash', on_behalf_of: other, line_items: [{ purchasable: once_plan }])
      pay_manually(placed)
      follow_up
      placed
    end

    expect(host_platform.billing_entitlements.find_by(order_id: paid_for.id).beneficiary).to eq(other)
  end
end
