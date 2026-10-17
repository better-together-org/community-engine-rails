# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::StripeOneTimePaymentSync do
  describe '#call' do
    let(:community) { create(:better_together_community) }
    let(:person) { create(:better_together_person) }
    let!(:billing_plan) do
      create(
        :better_together_billing_plan,
        :one_time,
        identifier: 'one-time-support',
        stripe_price_id: 'price_one_time_support'
      )
    end
    let!(:pay_customer) do
      Pay::Customer.create!(
        owner: community,
        processor: 'stripe',
        processor_id: 'cus_test_one_time_123'
      )
    end
    let(:checkout_session) do
      price = Struct.new(:id, keyword_init: true).new(id: billing_plan.stripe_price_id)
      line_item = Struct.new(:price, keyword_init: true).new(price:)
      line_items = Struct.new(:data, keyword_init: true).new(data: [line_item])

      Struct.new(
        :id,
        :customer,
        :amount_total,
        :currency,
        :metadata,
        :line_items,
        keyword_init: true
      ).new(
        id: 'cs_test_one_time_123',
        customer: pay_customer.processor_id,
        amount_total: 5_000,
        currency: 'cad',
        metadata: { 'bt_billing_plan_id' => billing_plan.id },
        line_items:
      )
    end

    it 'persists a local one-time payment record via the fallback pay_customer owner' do
      result = described_class.new.call(checkout_session:, payment_intent_id: 'pi_test_123')

      expect(result).to have_attributes(synced: true, billing_plan:)
      expect(result.one_time_payment).to have_attributes(
        owner: community,
        billing_plan:,
        stripe_checkout_session_id: 'cs_test_one_time_123',
        stripe_payment_intent_id: 'pi_test_123',
        amount_cents: 5_000,
        currency: 'cad',
        status: 'succeeded'
      )
      expect(result.one_time_payment.last_synced_at).to be_present
    end

    it 'resolves the billing plan by stripe_price_id when metadata omits the plan id' do
      checkout_session.metadata = {}

      result = described_class.new.call(checkout_session:, payment_intent_id: 'pi_test_123')

      expect(result).to have_attributes(synced: true, billing_plan:)
    end

    it 'prefers an explicit bt_billable_owner over the pay_customer owner' do
      checkout_session.metadata = {
        'bt_billing_plan_id' => billing_plan.id,
        'bt_billable_owner_type' => person.class.name,
        'bt_billable_owner_id' => person.id
      }

      result = described_class.new.call(checkout_session:, payment_intent_id: 'pi_test_123')

      expect(result.one_time_payment.owner).to eq(person)
    end

    it 'is idempotent for repeated syncs of the same checkout session' do
      described_class.new.call(checkout_session:, payment_intent_id: 'pi_test_123')

      expect do
        described_class.new.call(checkout_session:, payment_intent_id: 'pi_test_123')
      end.not_to change(BetterTogether::Billing::OneTimePayment, :count)
    end

    it 'returns owner_not_found when no owner can be resolved' do
      checkout_session.customer = 'cus_unknown'
      checkout_session.metadata = { 'bt_billing_plan_id' => billing_plan.id }

      result = described_class.new.call(checkout_session:, payment_intent_id: 'pi_test_123')

      expect(result).to have_attributes(synced: false, reason: :owner_not_found)
    end

    it 'returns billing_plan_not_found when no plan can be resolved' do
      checkout_session.metadata = {}
      checkout_session.line_items = Struct.new(:data, keyword_init: true).new(data: [])

      result = described_class.new.call(checkout_session:, payment_intent_id: 'pi_test_123')

      expect(result).to have_attributes(synced: false, reason: :billing_plan_not_found)
    end
  end
end
