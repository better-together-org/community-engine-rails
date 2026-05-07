# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::StripeEventProcessor do
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
    let(:subscription_object) do
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
    let(:event) do
      data = Struct.new(:object, keyword_init: true).new(object: subscription_object)
      payload = { id: 'evt_test_123', type: 'customer.subscription.created' }

      Struct.new(:id, :type, :data, :payload, keyword_init: true) do
        def to_hash
          payload
        end
      end.new(id: 'evt_test_123', type: 'customer.subscription.created', data:, payload:)
    end

    it 'logs the event and syncs a local BTS billing subscription' do
      described_class.new.call(event)

      billing_event = BetterTogether::Billing::Event.find_by!(processor: 'stripe', event_id: event.id)
      billing_subscription = BetterTogether::Billing::Subscription.find_by!(processor_subscription_id: 'sub_test_123')

      expect(billing_event.processing_status).to eq('processed')
      expect(billing_event.community).to eq(community)
      expect(billing_subscription.community).to eq(community)
      expect(billing_subscription.billing_plan).to eq(billing_plan)
      expect(billing_subscription.status).to eq('active')
      expect(billing_subscription.pay_customer_id).to eq('cus_test_123')
    end
  end
end
