# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::CreditBeneficiaryBalance do
  describe '#call' do
    let(:sponsor) { create(:better_together_person) }
    let(:beneficiary) { create(:better_together_community) }
    let(:sponsorship) { create(:better_together_billing_sponsorship, sponsor:, beneficiary:, status: 'active') }
    let(:balance_transaction) { Struct.new(:id, keyword_init: true).new(id: 'txn_test_credit_123') }

    context 'when the beneficiary already has a Stripe customer id' do
      before do
        Pay::Customer.create!(
          owner: beneficiary,
          processor: 'stripe',
          processor_id: 'cus_test_beneficiary_123',
          default: true
        )
      end

      it 'creates a Stripe balance transaction and records a local MonetaryContribution' do
        allow(Stripe::Customer).to receive(:create_balance_transaction).and_return(balance_transaction)

        result = described_class.new.call(sponsorship:, amount_cents: 5_000, currency: 'cad')

        expect(Stripe::Customer).to have_received(:create_balance_transaction).with(
          'cus_test_beneficiary_123',
          hash_including(amount: -5_000, currency: 'cad')
        )
        expect(result.monetary_contribution).to have_attributes(
          sponsorship:,
          amount_cents: 5_000,
          currency: 'cad',
          stripe_balance_transaction_id: 'txn_test_credit_123'
        )
      end

      it 'links the local audit record back to the funding one-time payment when provided' do
        one_time_payment = create(
          :better_together_billing_one_time_payment,
          owner: sponsor,
          amount_cents: 5_000,
          stripe_payment_intent_id: 'pi_test_source_123'
        )
        allow(Stripe::Customer).to receive(:create_balance_transaction).and_return(balance_transaction)

        result = described_class.new.call(sponsorship:, amount_cents: 5_000, currency: 'cad', one_time_payment:)

        expect(result.monetary_contribution.one_time_payment).to eq(one_time_payment)
        expect(result.monetary_contribution.stripe_payment_intent_id).to eq('pi_test_source_123')
      end
    end

    context 'when the beneficiary has no Stripe customer yet' do
      it 'forces Stripe customer creation before crediting the balance' do
        stripe_customer = Struct.new(:id, keyword_init: true).new(id: 'cus_test_newly_created')
        allow(Stripe::Customer).to receive_messages(
          create: stripe_customer,
          create_balance_transaction: balance_transaction
        )

        described_class.new.call(sponsorship:, amount_cents: 1_000, currency: 'cad')

        expect(Stripe::Customer).to have_received(:create)
        expect(Stripe::Customer).to have_received(:create_balance_transaction).with(
          'cus_test_newly_created',
          hash_including(amount: -1_000)
        )
      end
    end
  end
end
