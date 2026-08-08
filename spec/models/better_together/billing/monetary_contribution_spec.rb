# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::MonetaryContribution do
  subject(:monetary_contribution) do
    described_class.new(
      sponsorship:,
      amount_cents: 2_500,
      currency: 'cad',
      stripe_balance_transaction_id: 'txn_test_123'
    )
  end

  let(:sponsor) { create(:better_together_person) }
  let(:beneficiary) { create(:better_together_community) }
  let(:sponsorship) { create(:better_together_billing_sponsorship, sponsor:, beneficiary:, status: 'active') }

  it 'is valid with the required attributes' do
    expect(monetary_contribution).to be_valid
  end

  it 'requires a positive amount' do
    monetary_contribution.amount_cents = 0

    expect(monetary_contribution).not_to be_valid
    expect(monetary_contribution.errors[:amount_cents]).to be_present
  end

  it 'requires a unique stripe_balance_transaction_id' do
    monetary_contribution.save!
    duplicate = monetary_contribution.dup

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:stripe_balance_transaction_id]).to be_present
  end

  it 'delegates sponsor and beneficiary to its sponsorship' do
    expect(monetary_contribution.sponsor).to eq(sponsor)
    expect(monetary_contribution.beneficiary).to eq(beneficiary)
  end
end
