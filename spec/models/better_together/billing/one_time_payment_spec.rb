# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OneTimePayment do
  subject(:one_time_payment) do
    described_class.new(
      owner: community,
      billing_plan:,
      stripe_checkout_session_id: 'cs_test_one_time_123',
      stripe_payment_intent_id: 'pi_test_123',
      amount_cents: 5_000,
      currency: 'CAD'
    )
  end

  let(:community) { create(:better_together_community) }
  let(:billing_plan) { create(:better_together_billing_plan, :one_time) }

  it 'is valid with the required attributes' do
    expect(one_time_payment).to be_valid
  end

  it 'requires a unique stripe_checkout_session_id' do
    one_time_payment.save!
    duplicate = one_time_payment.dup

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:stripe_checkout_session_id]).to be_present
  end

  it 'rejects a negative amount' do
    one_time_payment.amount_cents = -1

    expect(one_time_payment).not_to be_valid
    expect(one_time_payment.errors[:amount_cents]).to be_present
  end

  it 'rejects an unsupported status' do
    one_time_payment.status = 'pending'

    expect(one_time_payment).not_to be_valid
    expect(one_time_payment.errors[:status]).to be_present
  end

  it 'defaults to succeeded' do
    one_time_payment.save!

    expect(one_time_payment).to be_succeeded
    expect(one_time_payment).not_to be_refunded
  end

  it 'can belong to a person owner' do
    person = create(:better_together_person)
    one_time_payment.owner = person

    expect(one_time_payment).to be_valid
    expect(one_time_payment.owner).to eq(person)
  end
end
