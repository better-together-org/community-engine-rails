# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::StripeCommunityReconciliation do
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
    let(:subscription_list) do
      Struct.new(:records) do
        def auto_paging_each(&)
          records.each(&)
        end
      end.new([subscription])
    end

    it 'synchronizes subscriptions returned by Stripe' do
      allow(Stripe::Subscription).to receive(:list).and_return(subscription_list)

      result = described_class.new.call(community:)

      expect(result.synced_count).to eq(1)
      expect(result.subscription_ids).to eq(['sub_test_123'])
      pay_sub = Pay::Customer.find_by(processor: 'stripe', processor_id: 'cus_test_123')
                             .subscriptions.find_by(processor_id: 'sub_test_123')
      expect(pay_sub&.billing_subscription_record).to be_present
    end
  end
end
