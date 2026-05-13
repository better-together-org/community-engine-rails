# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::StripeCheckoutSessionSync do
  describe '#call' do
    let(:community) { create(:better_together_community) }
    let(:person) { create(:better_together_person) }
    let!(:billing_plan) do
      create(
        :better_together_billing_plan,
        identifier: 'community-ops',
        stripe_price_id: 'price_community_ops'
      )
    end
    let!(:pay_customer) do
      Pay::Customer.create!(
        owner: community,
        processor: 'stripe',
        processor_id: 'cus_test_123'
      )
    end
    let!(:pay_subscription) do
      Pay::Subscription.create!(
        customer: pay_customer,
        name: 'default',
        processor_id: 'sub_test_123',
        processor_plan: billing_plan.stripe_price_id,
        status: 'active',
        current_period_start: Time.current.beginning_of_day,
        current_period_end: 1.month.from_now.beginning_of_day
      )
    end
    let(:subscription) do
      price = Struct.new(:id, keyword_init: true).new(id: billing_plan.stripe_price_id)
      line_item = Struct.new(:price, keyword_init: true).new(price:)
      items = Struct.new(:data, keyword_init: true).new(data: [line_item])

      Struct.new(
        :id,
        :customer,
        :status,
        :current_period_start,
        :current_period_end,
        :cancel_at_period_end,
        :metadata,
        :items,
        keyword_init: true
      ).new(
        id: 'sub_test_123',
        customer: pay_customer.processor_id,
        status: 'active',
        current_period_start: 1_777_777_777,
        current_period_end: 1_780_000_000,
        cancel_at_period_end: false,
        metadata: { 'bt_billing_plan_id' => billing_plan.id, 'bt_community_id' => community.id },
        items:
      )
    end
    let(:checkout_session) do
      Struct.new(:id, :customer, :subscription, :metadata, keyword_init: true).new(
        id: 'cs_test_123',
        customer: pay_customer.processor_id,
        subscription:,
        metadata: { 'bt_community_id' => community.id }
      )
    end

    it 'retrieves the checkout session and syncs the subscription' do
      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(checkout_session)

      result = described_class.new.call(checkout_session_id: 'cs_test_123')

      expect(result).to have_attributes(synced: true, billing_plan:)
      expect(result.billing_subscription.latest_checkout_session_id).to eq('cs_test_123')
      expect(Stripe::Checkout::Session).to have_received(:retrieve).with(
        hash_including(id: 'cs_test_123')
      )
    end

    it 'preserves person-sponsored ownership for a community beneficiary from checkout metadata' do
      person_pay_customer = Pay::Customer.create!(
        owner: person,
        processor: 'stripe',
        processor_id: 'cus_test_person'
      )
      Pay::Subscription.create!(
        customer: person_pay_customer,
        name: 'default',
        processor_id: 'sub_person_test_123',
        processor_plan: billing_plan.stripe_price_id,
        status: 'active',
        current_period_start: Time.current.beginning_of_day,
        current_period_end: 1.month.from_now.beginning_of_day
      )
      sponsored_subscription = subscription.dup
      sponsored_subscription.id = 'sub_person_test_123'
      sponsored_subscription.customer = person_pay_customer.processor_id
      sponsored_subscription.metadata = {
        'bt_billable_owner_type' => person.class.name,
        'bt_billable_owner_id' => person.id,
        'bt_beneficiary_type' => community.class.name,
        'bt_beneficiary_id' => community.id,
        'bt_billing_plan_id' => billing_plan.id
      }
      sponsored_checkout_session = checkout_session.dup
      sponsored_checkout_session.customer = person_pay_customer.processor_id
      sponsored_checkout_session.subscription = sponsored_subscription
      sponsored_checkout_session.metadata = {
        'bt_billable_owner_type' => person.class.name,
        'bt_billable_owner_id' => person.id,
        'bt_beneficiary_type' => community.class.name,
        'bt_beneficiary_id' => community.id
      }

      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(sponsored_checkout_session)

      result = described_class.new.call(checkout_session_id: 'cs_test_person')

      expect(result).to have_attributes(synced: true, billing_plan:)
      expect(result.billing_subscription.pay_subscription.customer.owner).to eq(person)
    end

    it 'preserves community-sponsored ownership for another community beneficiary from checkout metadata' do
      sponsor_community = create(:better_together_community, name: 'Collective Sponsor')
      sponsor_pay_customer = Pay::Customer.create!(
        owner: sponsor_community,
        processor: 'stripe',
        processor_id: 'cus_test_sponsor_community'
      )
      Pay::Subscription.create!(
        customer: sponsor_pay_customer,
        name: 'default',
        processor_id: 'sub_sponsor_test_123',
        processor_plan: billing_plan.stripe_price_id,
        status: 'active',
        current_period_start: Time.current.beginning_of_day,
        current_period_end: 1.month.from_now.beginning_of_day
      )
      sponsored_subscription = subscription.dup
      sponsored_subscription.id = 'sub_sponsor_test_123'
      sponsored_subscription.customer = sponsor_pay_customer.processor_id
      sponsored_subscription.metadata = {
        'bt_billable_owner_type' => sponsor_community.class.name,
        'bt_billable_owner_id' => sponsor_community.id,
        'bt_beneficiary_type' => community.class.name,
        'bt_beneficiary_id' => community.id,
        'bt_billing_plan_id' => billing_plan.id
      }
      sponsored_checkout_session = checkout_session.dup
      sponsored_checkout_session.customer = sponsor_pay_customer.processor_id
      sponsored_checkout_session.subscription = sponsored_subscription
      sponsored_checkout_session.metadata = {
        'bt_billable_owner_type' => sponsor_community.class.name,
        'bt_billable_owner_id' => sponsor_community.id,
        'bt_beneficiary_type' => community.class.name,
        'bt_beneficiary_id' => community.id
      }

      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(sponsored_checkout_session)

      result = described_class.new.call(checkout_session_id: 'cs_test_sponsor_community')

      expect(result).to have_attributes(synced: true, billing_plan:)
      expect(result.billing_subscription.pay_subscription.customer.owner).to eq(sponsor_community)
    end
  end
end
