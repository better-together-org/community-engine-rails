# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::StripeFinancialEventSync do
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
    let!(:billing_subscription) do
      create(
        :better_together_billing_subscription,
        billable_owner: community,
        beneficiary: community,
        billing_plan:,
        processor_subscription_id: 'sub_test_123',
        pay_customer_id: pay_customer.processor_id,
        status: 'active'
      )
    end

    it 'marks local subscriptions as past_due when Stripe reports a failed invoice payment' do
      invoice_object = Struct.new(
        :id,
        :object,
        :subscription,
        :customer,
        :status,
        :metadata,
        :last_payment_error,
        keyword_init: true
      ).new(
        id: 'in_test_123',
        object: 'invoice',
        subscription: billing_subscription.processor_subscription_id,
        customer: pay_customer.processor_id,
        status: 'open',
        metadata: {},
        last_payment_error: Struct.new(:message, keyword_init: true).new(message: 'Card was declined.')
      )
      event = Struct.new(:id, :type, :data, keyword_init: true).new(
        id: 'evt_invoice_failed_123',
        type: 'invoice.payment_failed',
        data: Struct.new(:object, keyword_init: true).new(object: invoice_object)
      )

      result = described_class.new.call(event:)

      expect(result.synced).to be(true)
      expect(result.billable_owner).to eq(community)
      expect(result.beneficiary).to eq(community)
      expect(result.billing_subscription).to eq(billing_subscription)
      expect(result.processing_status).to eq('failed')
      expect(result.error_message).to include('Stripe reported that an invoice payment failed.')
      expect(result.error_message).to include('Card was declined.')

      billing_subscription.reload
      expect(billing_subscription.status).to eq('past_due')
      expect(billing_subscription.sync_source).to eq('stripe_financial_event')
      expect(billing_subscription.latest_processor_event_id).to eq('evt_invoice_failed_123')
      expect(billing_subscription.metadata).to include(
        'last_financial_event_type' => 'invoice.payment_failed',
        'last_invoice_id' => 'in_test_123',
        'last_invoice_status' => 'open'
      )
    end

    it 'returns processed results for successful invoice settlement events' do
      invoice_object = Struct.new(
        :id,
        :object,
        :subscription,
        :customer,
        :status,
        :metadata,
        keyword_init: true
      ).new(
        id: 'in_test_paid_123',
        object: 'invoice',
        subscription: billing_subscription.processor_subscription_id,
        customer: pay_customer.processor_id,
        status: 'paid',
        metadata: {}
      )
      event = Struct.new(:id, :type, :data, keyword_init: true).new(
        id: 'evt_invoice_paid_123',
        type: 'invoice.paid',
        data: Struct.new(:object, keyword_init: true).new(object: invoice_object)
      )

      result = described_class.new.call(event:)

      expect(result.processing_status).to eq('processed')
      expect(result.error_message).to be_nil
      expect(billing_subscription.reload.status).to eq('active')
    end

    it 'resolves disputes through stored Pay charges when no subscription id is present on the event object' do
      pay_subscription = Pay::Subscription.create!(
        customer: pay_customer,
        name: 'default',
        processor_id: billing_subscription.processor_subscription_id,
        processor_plan: billing_plan.stripe_price_id,
        status: 'active'
      )
      Pay::Charge.create!(
        customer: pay_customer,
        subscription: pay_subscription,
        processor_id: 'ch_test_123',
        amount: billing_plan.amount_cents,
        currency: 'cad'
      )
      dispute_object = Struct.new(:id, :object, :charge, :reason, keyword_init: true).new(
        id: 'dp_test_123',
        object: 'dispute',
        charge: 'ch_test_123',
        reason: 'fraudulent'
      )
      event = Struct.new(:id, :type, :data, keyword_init: true).new(
        id: 'evt_dispute_created_123',
        type: 'charge.dispute.created',
        data: Struct.new(:object, keyword_init: true).new(object: dispute_object)
      )

      result = described_class.new.call(event:)

      expect(result.synced).to be(true)
      expect(result.billable_owner).to eq(community)
      expect(result.beneficiary).to eq(community)
      expect(result.billing_subscription).to eq(billing_subscription)
      expect(result.processing_status).to eq('failed')
      expect(result.error_message).to include('Stripe opened a dispute for a related charge.')
      expect(result.error_message).to include('Reason: fraudulent.')
      expect(billing_subscription.reload.metadata).to include(
        'last_charge_id' => 'ch_test_123',
        'last_dispute_reason' => 'fraudulent'
      )
    end
  end
end
