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

  describe 'app-owned grace period' do
    it 'keeps hosted access active and reports :grace for a lapsed subscription within its grace period' do
      subscription = create_subscription_for(owner: community, billing_plan: create(:better_together_billing_plan), status: 'canceled')
      subscription.sync_lapse_state!

      result = resolver.call(community:)

      expect(result).to be_grace_period
      expect(result.hosted_access_active).to be(true)
      expect(result.grace_period_ends_at).to be_present
    end

    it 'reports :inactive and cuts hosted access once the grace period has expired' do
      subscription = create_subscription_for(owner: community, billing_plan: create(:better_together_billing_plan), status: 'canceled')
      subscription.sync_lapse_state!

      result = travel_to(8.days.from_now) { resolver.call(community:) }

      expect(result).to be_inactive
      expect(result.hosted_access_active).to be(false)
    end

    it 'reports :inactive for a canceled subscription that was never lapse-tracked (fails closed, no unbounded grace)' do
      create_subscription_for(owner: community, billing_plan: create(:better_together_billing_plan), status: 'canceled')

      result = resolver.call(community:)

      expect(result).to be_inactive
      expect(result.hosted_access_active).to be(false)
    end
  end

  describe 'agreement with Billing::EntitlementResolver' do
    let(:granting_plan) do
      create(:better_together_billing_plan, metadata: { 'grants_entitlements' => ['hosted_access'] })
    end

    # hosted_access_active (not the narrower #active?, which excludes
    # :attention/:grace) is the correct comparison point — both it and
    # entitled_to? answer "does this holder currently have functional
    # access," not "is status exactly :active."
    let(:sync_and_compare) do
      lambda do |status:|
        subscription = create_subscription_for(owner: community, billing_plan: granting_plan, status:)
        subscription.sync_lapse_state!
        BetterTogether::Billing::EntitlementGrantSync.new.call(
          billable_owner: community, billing_plan: granting_plan, source: subscription
        )

        resolver.call(community:)
      end
    end

    it 'agrees for an active subscription' do
      result = sync_and_compare.call(status: 'active')

      expect(result.hosted_access_active).to be(true)
      expect(community.entitled_to?('hosted_access')).to eq(result.hosted_access_active)
    end

    it 'agrees for a past_due (:attention) subscription — Stripe\'s own dunning window still grants access' do
      result = sync_and_compare.call(status: 'past_due')

      expect(result).to be_attention_needed
      expect(result.hosted_access_active).to be(true)
      expect(community.entitled_to?('hosted_access')).to eq(result.hosted_access_active)
    end

    it 'agrees for a lapsed subscription within its grace period' do
      result = sync_and_compare.call(status: 'canceled')

      expect(result).to be_grace_period
      expect(result.hosted_access_active).to be(true)
      expect(community.entitled_to?('hosted_access')).to eq(result.hosted_access_active)
    end

    it 'agrees once the grace period has expired' do
      sync_and_compare.call(status: 'canceled')

      result = travel_to(8.days.from_now) { resolver.call(community:) }
      # A fresh sync (as would happen on the subscription's next webhook)
      # is what actually revokes the entitlement — resolver_result and
      # entitled_to? still agree on the pre-revocation snapshot here.
      travel_to(8.days.from_now) do
        subscription = BetterTogether::Billing::Subscription.current_for_owner(community)
        BetterTogether::Billing::EntitlementGrantSync.new.call(
          billable_owner: community, billing_plan: granting_plan, source: subscription
        )
      end

      expect(result.hosted_access_active).to be(false)
      expect(community.entitled_to?('hosted_access')).to eq(result.hosted_access_active)
    end

    it 'agrees for a community with no subscription at all' do
      result = resolver.call(community:)

      expect(result.hosted_access_active).to be(false)
      expect(community.entitled_to?('hosted_access')).to eq(result.hosted_access_active)
    end
  end
end
