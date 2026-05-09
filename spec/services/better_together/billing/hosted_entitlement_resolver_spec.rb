# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::HostedEntitlementResolver do
  subject(:resolver) { described_class.new }

  let(:community) { create(:better_together_community) }

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
    create(
      :better_together_billing_subscription,
      billable_owner: community,
      beneficiary: community,
      billing_plan: plan,
      status: 'active'
    )

    result = resolver.call(community:)

    expect(result).to be_active
    expect(result.hosted_access_active).to be(true)
    expect(result.hosted_access_level).to eq('Partner')
    expect(result.support_tier).to eq('Priority')
    expect(result.community_capacity_tier).to eq('Growth')
  end

  it 'marks past-due subscriptions as needing attention' do
    create(
      :better_together_billing_subscription,
      billable_owner: community,
      beneficiary: community,
      billing_plan: create(:better_together_billing_plan),
      status: 'past_due'
    )

    result = resolver.call(community:)

    expect(result).to be_attention_needed
    expect(result.hosted_access_active).to be(true)
  end
end
