# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Refund do
  include_context 'with orders fixtures'

  let(:order) { create(:better_together_billing_order, :awaiting_payment, total_cents: 4500) }
  let(:payment) { create(:better_together_billing_payment, order:, status: 'succeeded', amount_cents: 4500) }

  def refund(**attrs) = build(:better_together_billing_refund, payment:, **attrs)

  describe 'its platform' do
    it 'is its payment\'s, never the request\'s' do
      Current.platform = create(:better_together_platform)
      built = payment.refunds.build(amount_cents: 100, currency: 'USD', idempotency_key: 'k')

      expect(built).to be_valid
      expect(built.platform_id).to eq(host_platform.id)
    ensure
      Current.platform = nil
    end

    it 'has a NOT NULL column' do
      expect(described_class.columns_hash.fetch('platform_id').null).to be(false)
    end
  end

  it 'is valid for part of what was paid' do
    expect(refund(amount_cents: 1000)).to be_valid
  end

  it 'cannot be more than is left to refund' do
    create(:better_together_billing_refund, payment:, amount_cents: 4000)
    too_much = refund(amount_cents: 1000)

    expect(too_much).not_to be_valid
    expect(too_much.errors.details[:amount_cents]).to include(a_hash_including(error: :greater_than_refundable))
  end

  it 'cannot refund a payment that was never received' do
    pending_payment = create(:better_together_billing_payment, order:)

    expect(build(:better_together_billing_refund, payment: pending_payment)).not_to be_valid
  end

  it 'has a known status and reason, a positive amount, and a key unique per platform' do
    expect(refund(status: 'lost')).not_to be_valid
    expect(refund(reason: 'because')).not_to be_valid
    expect(refund(amount_cents: 0)).not_to be_valid
    create(:better_together_billing_refund, payment:, idempotency_key: 'k1', amount_cents: 100)
    expect(refund(idempotency_key: 'k1')).not_to be_valid
  end

  it 'counts money given back, or on its way, but not a failed one' do
    expect(refund(status: 'recorded')).to be_counted
    expect(refund(status: 'pending')).to be_counted
    expect(refund(status: 'failed')).not_to be_counted
  end
end
