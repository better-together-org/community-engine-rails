# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::StripeSubscriptionSync do
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
    let(:event) { Struct.new(:id, keyword_init: true).new(id: 'evt_test_123') }

    it 'writes local sync tracking fields' do
      result = described_class.new.call(
        subscription:,
        source: 'checkout_return',
        event:,
        checkout_session_id: 'cs_test_123'
      )

      expect(result).to have_attributes(synced: true, community:, billing_plan:)
      expect(result.billing_subscription).to have_attributes(
        latest_processor_event_id: 'evt_test_123',
        latest_checkout_session_id: 'cs_test_123',
        sync_source: 'checkout_return'
      )
      expect(result.billing_subscription.last_synced_at).to be_present
    end

    it 'persists a person-owned billing subscription without requiring a legacy community id' do
      person_plan = create(
        :better_together_billing_plan,
        identifier: 'personal-support',
        stripe_price_id: 'price_personal_support',
        metadata: { 'eligible_billable_owner_types' => ['person'] }
      )
      person_pay_customer = Pay::Customer.create!(
        owner: person,
        processor: 'stripe',
        processor_id: 'cus_person_test_123'
      )
      person_price = Struct.new(:id, keyword_init: true).new(id: person_plan.stripe_price_id)
      person_line_item = Struct.new(:price, keyword_init: true).new(price: person_price)
      person_items = Struct.new(:data, keyword_init: true).new(data: [person_line_item])
      person_subscription = Struct.new(
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
        id: 'sub_person_test_123',
        customer: person_pay_customer.processor_id,
        status: 'active',
        current_period_start: 1_777_777_777,
        current_period_end: 1_780_000_000,
        cancel_at_period_end: false,
        metadata: {
          'bt_billing_plan_id' => person_plan.id,
          'bt_billable_owner_type' => person.class.name,
          'bt_billable_owner_id' => person.id,
          'bt_beneficiary_type' => person.class.name,
          'bt_beneficiary_id' => person.id
        },
        items: person_items
      )

      result = described_class.new.call(subscription: person_subscription, source: 'checkout_return')

      expect(result).to have_attributes(synced: true, billable_owner: person, beneficiary: person, billing_plan: person_plan)
      expect(result.billing_subscription.community_id).to be_nil
    end
  end
end
