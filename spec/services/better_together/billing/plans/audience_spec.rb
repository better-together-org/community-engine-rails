# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Plans::Audience do
  include_context 'with entitlement fixtures'

  let(:free) do
    { processor: nil, processor_price_id: nil, processor_product_id: nil, amount_cents: 0, currency: 'USD', accepted_payment_methods: [] }
  end
  let(:member_plan) { create(:better_together_billing_plan, :one_time, **free) }
  let(:perk_plan) { create(:better_together_billing_plan, :one_time, **free) }

  def audience(person) = described_class.call(platform: host_platform, person:)

  # A live entitlement for the buyer, from a subscription or (without one) from a free one-time order.
  def give(plan, via_subscription: false)
    source = if via_subscription
               { pay_subscription: start_subscription(payer: create(:better_together_person)).pay_subscription }
             else
               { order: place_order(buyer: create(:better_together_person), purpose: 'one_time', line_items: [{ purchasable: plan }]) }
             end
    host_platform.billing_entitlements.create!(plan:, beneficiary: buyer, starts_at: Time.current, **source)
  end

  it 'is neither for a visitor' do
    expect(audience(nil)).to have_attributes(member: false, subscriber: false)
  end

  it 'is neither for a person who holds nothing' do
    expect(audience(buyer)).to have_attributes(member: false, subscriber: false)
  end

  it 'is a member when a live entitlement comes from a plan that gives a membership role' do
    add_grant('membership_role', { 'joinable' => 'platform', 'role' => supporter_role.identifier }, plan: member_plan)
    give(member_plan)

    expect(audience(buyer)).to have_attributes(member: true, subscriber: false)
  end

  it 'is not a member for an entitlement from a plan that gives no membership role' do
    give(perk_plan)

    expect(audience(buyer)).to have_attributes(member: false)
  end

  it 'is a subscriber when a live entitlement comes from a subscription' do
    give(sub_plan, via_subscription: true)

    expect(audience(buyer)).to have_attributes(subscriber: true)
  end

  it 'stops counting an entitlement that is no longer live' do
    give(sub_plan, via_subscription: true).update!(status: 'revoked')

    expect(audience(buyer)).to have_attributes(member: false, subscriber: false)
  end

  describe 'Plan.open_to' do
    let(:plans) { BetterTogether::Billing::Plan }
    let(:ours) { %w[open-plan members-plan subs-plan either-plan] }
    let(:result) { described_class::Result }
    let(:identifiers) { ->(audience) { plans.where(identifier: ours).open_to(audience).pluck(:identifier) } }

    before do
      create(:better_together_billing_plan, identifier: 'open-plan')
      create(:better_together_billing_plan, identifier: 'members-plan', restricted_to_members: true)
      create(:better_together_billing_plan, identifier: 'subs-plan', restricted_to_subscribers: true)
      create(:better_together_billing_plan, identifier: 'either-plan', restricted_to_members: true, restricted_to_subscribers: true)
    end

    it 'gives only unrestricted plans to someone who is neither' do
      expect(identifiers.call(result.new(member: false, subscriber: false))).to eq(['open-plan'])
    end

    it 'adds members-only and either-kind plans for a member' do
      expect(identifiers.call(result.new(member: true, subscriber: false))).to contain_exactly('open-plan', 'members-plan', 'either-plan')
    end

    it 'adds subscribers-only and either-kind plans for a subscriber' do
      expect(identifiers.call(result.new(member: false, subscriber: true))).to contain_exactly('open-plan', 'subs-plan', 'either-plan')
    end

    it 'gives everything to someone who is both' do
      expect(identifiers.call(result.new(member: true,
                                         subscriber: true))).to contain_exactly('open-plan',
                                                                                'members-plan', 'subs-plan', 'either-plan')
    end
  end
end
