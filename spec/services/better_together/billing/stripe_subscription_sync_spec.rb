# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::StripeSubscriptionSync do
  describe '#call' do
    let(:community) { create(:better_together_community) }
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
  end
end
