# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::EntitlementGrantSync do
  subject(:sync) { described_class.new }

  let(:holder) { create(:better_together_community) }
  let(:plan) { create('better_together/billing/plan', metadata: { 'grants_entitlements' => ['hosted_access'] }) }

  describe 'with a Billing::Subscription source' do
    let(:pay_customer) { create('pay/customer', owner: holder) }
    let(:pay_subscription) { create('pay/subscription', customer: pay_customer, status: 'active') }
    let(:subscription) { create('better_together/billing/subscription', pay_subscription:, billing_plan: plan) }

    it 'grants the declared entitlement when the subscription is access_active' do
      sync.call(billable_owner: holder, billing_plan: plan, source: subscription)

      expect(holder.entitled_to?('hosted_access')).to be(true)
      entitlement = BetterTogether::Billing::Entitlement.for_holder_and_key(holder, 'hosted_access').sole
      expect(entitlement.source).to eq(subscription)
      expect(entitlement.billing_plan).to eq(plan)
    end

    it 'revokes a previously-granted entitlement once the subscription is no longer access_active' do
      sync.call(billable_owner: holder, billing_plan: plan, source: subscription)
      expect(holder.entitled_to?('hosted_access')).to be(true)

      pay_subscription.update!(status: 'canceled')
      subscription.sync_lapse_state!
      travel_to(8.days.from_now) { sync.call(billable_owner: holder, billing_plan: plan, source: subscription) }

      expect(holder.entitled_to?('hosted_access')).to be(false)
    end

    it 'keeps the entitlement granted while the subscription is within its grace period' do
      sync.call(billable_owner: holder, billing_plan: plan, source: subscription)

      pay_subscription.update!(status: 'canceled')
      subscription.sync_lapse_state!
      sync.call(billable_owner: holder, billing_plan: plan, source: subscription)

      expect(holder.entitled_to?('hosted_access')).to be(true)
    end
  end

  describe 'with a Billing::OneTimePayment source' do
    let(:one_time_payment) do
      create('better_together/billing/one_time_payment', owner: holder, billing_plan: plan)
    end

    it 'grants the declared entitlement unconditionally — a completed payment stays granted' do
      sync.call(billable_owner: holder, billing_plan: plan, source: one_time_payment)

      expect(holder.entitled_to?('hosted_access')).to be(true)
      entitlement = BetterTogether::Billing::Entitlement.for_holder_and_key(holder, 'hosted_access').sole
      expect(entitlement.source).to eq(one_time_payment)
    end
  end

  it 'is a no-op when billable_owner is blank' do
    plan_with_grant = plan
    expect do
      sync.call(billable_owner: nil, billing_plan: plan_with_grant, source: nil)
    end.not_to change(BetterTogether::Billing::Entitlement, :count)
  end

  it 'is a no-op when billing_plan is blank' do
    expect do
      sync.call(billable_owner: holder, billing_plan: nil, source: nil)
    end.not_to change(BetterTogether::Billing::Entitlement, :count)
  end

  it 'is a no-op when the plan declares no entitlements' do
    bare_plan = create('better_together/billing/plan')

    expect do
      sync.call(billable_owner: holder, billing_plan: bare_plan, source: nil)
    end.not_to change(BetterTogether::Billing::Entitlement, :count)
  end

  it 'is a no-op when billable_owner cannot hold entitlements' do
    non_holder = create('better_together/billing/plan')

    expect do
      sync.call(billable_owner: non_holder, billing_plan: plan, source: nil)
    end.not_to change(BetterTogether::Billing::Entitlement, :count)
  end
end
