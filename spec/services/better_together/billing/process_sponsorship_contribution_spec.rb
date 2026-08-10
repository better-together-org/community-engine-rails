# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ProcessSponsorshipContribution do
  let(:sponsor) { create(:better_together_community) }
  let(:beneficiary) { create(:better_together_community) }
  let(:one_time_payment) { create('better_together/billing/one_time_payment', owner: sponsor, amount_cents: 2_500) }
  let(:balance_transaction) { Struct.new(:id, keyword_init: true).new(id: 'txn_test_process_contribution') }

  def checkout_session_for(beneficiary)
    Struct.new(:metadata, keyword_init: true).new(
      metadata: {
        'bt_sponsorship_beneficiary_type' => beneficiary.class.name,
        'bt_sponsorship_beneficiary_id' => beneficiary.id
      }
    )
  end

  before do
    Pay::Customer.create!(owner: beneficiary, processor: 'stripe', processor_id: 'cus_test_process_contribution',
                          default: true)
    allow(Stripe::Customer).to receive(:create_balance_transaction).and_return(balance_transaction)
  end

  it 'creates a standing sponsorship and credits the beneficiary balance' do
    result = described_class.new.call(one_time_payment:, checkout_session: checkout_session_for(beneficiary))

    expect(result.beneficiary).to eq(beneficiary)
    expect(result.credit_result.already_credited).to be(false)
    expect(
      BetterTogether::Billing::Sponsorship.status_active.for_sponsor(sponsor).for_beneficiary(beneficiary)
    ).to exist
    expect(BetterTogether::Billing::MonetaryContribution.sole.one_time_payment).to eq(one_time_payment)
  end

  it 'reuses an existing active sponsorship rather than creating a duplicate' do
    existing = create('better_together/billing/sponsorship', sponsor:, beneficiary:, status: 'active')

    result = described_class.new.call(one_time_payment:, checkout_session: checkout_session_for(beneficiary))

    expect(result.credit_result.monetary_contribution.sponsorship).to eq(existing)
    expect(BetterTogether::Billing::Sponsorship.for_sponsor(sponsor).for_beneficiary(beneficiary).count).to eq(1)
  end

  it 'is a no-op when one_time_payment is blank' do
    expect(
      described_class.new.call(one_time_payment: nil, checkout_session: checkout_session_for(beneficiary))
    ).to be_nil
    expect(Stripe::Customer).not_to have_received(:create_balance_transaction)
  end

  it 'is a no-op when the checkout session carries no resolvable beneficiary metadata' do
    empty_session = Struct.new(:metadata, keyword_init: true).new(metadata: {})

    expect(described_class.new.call(one_time_payment:, checkout_session: empty_session)).to be_nil
    expect(Stripe::Customer).not_to have_received(:create_balance_transaction)
  end

  it 'is idempotent when called twice for the same one_time_payment (e.g. webhook + browser return both firing)' do
    first = described_class.new.call(one_time_payment:, checkout_session: checkout_session_for(beneficiary))
    second = described_class.new.call(one_time_payment:, checkout_session: checkout_session_for(beneficiary))

    expect(first.credit_result.already_credited).to be(false)
    expect(second.credit_result.already_credited).to be(true)
    expect(Stripe::Customer).to have_received(:create_balance_transaction).once
    expect(BetterTogether::Billing::MonetaryContribution.count).to eq(1)
  end
end
