# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::HostedEntitlementResolver do
  subject(:resolver) { described_class.new }

  let(:community) { create(:better_together_community) }

  def create_subscription_for(owner:, billing_plan:, status:, updated_at: nil)
    pay_customer = create('pay/customer', owner:)
    pay_subscription = create('pay/subscription', customer: pay_customer, status:)
    attributes = { pay_subscription:, billing_plan: }
    attributes[:updated_at] = updated_at if updated_at

    create(:better_together_billing_subscription, **attributes)
  end

  it 'returns inactive state when no billing subscription is present' do
    result = resolver.call(community:)

    expect(result).to be_inactive
    expect(result.hosted_access_active).to be(false)
    expect(result.hosted_access_level).to be_nil
  end

  it 'resolves hosted entitlement from an active community subscription' do
    plan = create(
      :better_together_billing_plan,
      metadata: {
        'hosted_access_level' => 'Partner',
        'support_tier' => 'Priority',
        'community_capacity_tier' => 'Growth'
      }
    )
    create_subscription_for(owner: community, billing_plan: plan, status: 'active')

    result = resolver.call(community:)

    expect(result).to be_active
    expect(result.hosted_access_active).to be(true)
    expect(result.hosted_access_level).to eq('Partner')
    expect(result.support_tier).to eq('Priority')
    expect(result.community_capacity_tier).to eq('Growth')
  end

  it 'marks past-due subscriptions as needing attention' do
    create_subscription_for(owner: community, billing_plan: create(:better_together_billing_plan), status: 'past_due')

    result = resolver.call(community:)

    expect(result).to be_attention_needed
    expect(result.hosted_access_active).to be(true)
  end

  it 'prefers an active subscription over a newer canceled subscription' do
    active_plan = create(:better_together_billing_plan, metadata: { 'hosted_access_level' => 'Steady' })
    canceled_plan = create(:better_together_billing_plan, metadata: { 'hosted_access_level' => 'Canceled' })
    create_subscription_for(owner: community, billing_plan: active_plan, status: 'active', updated_at: 2.days.ago)
    create_subscription_for(owner: community, billing_plan: canceled_plan, status: 'canceled', updated_at: 1.hour.ago)

    result = resolver.call(community:)

    expect(result).to be_active
    expect(result.hosted_access_level).to eq('Steady')
  end
end
