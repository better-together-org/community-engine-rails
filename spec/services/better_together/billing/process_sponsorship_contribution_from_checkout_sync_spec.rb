# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ProcessSponsorshipContributionFromCheckoutSync do
  let(:sponsor) { create(:better_together_community) }
  let(:beneficiary) { create(:better_together_community, accepts_sponsorship: true) }
  let(:one_time_payment) { create('better_together/billing/one_time_payment', owner: sponsor, amount_cents: 2_500) }
  let(:balance_transaction) { Struct.new(:id, keyword_init: true).new(id: 'txn_test_checkout_sync_contribution') }
  let(:checkout_session) do
    Struct.new(:metadata, keyword_init: true).new(
      metadata: {
        'bt_sponsorship_beneficiary_type' => beneficiary.class.name,
        'bt_sponsorship_beneficiary_id' => beneficiary.id
      }
    )
  end
  let(:sync_result) do
    BetterTogether::Billing::StripeCheckoutSessionSync::Result.new(synced: true, one_time_payment:, checkout_session:)
  end

  before do
    Pay::Customer.create!(owner: beneficiary, processor: 'stripe', processor_id: 'cus_test_checkout_sync_contribution',
                          default: true)
    allow(Stripe::Customer).to receive(:create_balance_transaction).and_return(balance_transaction)
  end

  it 'credits the beneficiary and returns a credited result' do
    result = described_class.new.call(sync_result)

    expect(result.credited).to be(true)
    expect(result.already_credited).to be(false)
    expect(result.beneficiary).to eq(beneficiary)
    expect(BetterTogether::Billing::MonetaryContribution.sole.one_time_payment).to eq(one_time_payment)
  end

  it 'reports already_credited without re-crediting when called twice' do
    described_class.new.call(sync_result)
    second = described_class.new.call(sync_result)

    expect(second.already_credited).to be(true)
    expect(Stripe::Customer).to have_received(:create_balance_transaction).once
  end

  it 'is a no-op when the sync result has no one_time_payment (e.g. a subscription sync)' do
    subscription_result = BetterTogether::Billing::StripeCheckoutSessionSync::Result.new(synced: true)

    expect(described_class.new.call(subscription_result)).to be_nil
    expect(Stripe::Customer).not_to have_received(:create_balance_transaction)
  end

  it 'is a no-op when the sync result itself is nil' do
    expect(described_class.new.call(nil)).to be_nil
    expect(Stripe::Customer).not_to have_received(:create_balance_transaction)
  end

  it 'catches a StripeError from the crediting call and returns an error result instead of raising' do
    allow(Stripe::Customer).to receive(:create_balance_transaction).and_raise(Stripe::StripeError, 'card declined')

    result = described_class.new.call(sync_result)

    expect(result.credited).to be(false)
    expect(result.error).to be_a(Stripe::StripeError)
  end
end
