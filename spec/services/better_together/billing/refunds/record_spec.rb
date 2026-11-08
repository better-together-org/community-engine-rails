# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Refunds::Record do
  include_context 'with orders fixtures'

  let(:person) { create(:better_together_person) }
  let(:order) { place_order }
  let(:payment) do
    BetterTogether::Billing::Payments::Succeed.call(
      BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 4500, idempotency_key: 'req')
    )
  end

  def record(**attrs) = described_class.call(payment:, amount_cents: 1000, idempotency_key: 'refund-1', **attrs)

  it 'records money given back, with who recorded it and why, and moves the payment and order' do
    refund = record(reason: 'requested_by_buyer', recorded_by: person)

    expect(refund).to have_attributes(status: 'recorded', amount_cents: 1000, reason: 'requested_by_buyer', recorded_by: person,
                                      platform_id: host_platform.id)
    expect(payment.reload).to be_partially_refunded
    expect(order.reload).to be_partially_refunded
  end

  it 'refunds in full across several refunds' do
    record(amount_cents: 1000, idempotency_key: 'one')
    record(amount_cents: 3500, idempotency_key: 'two')

    expect(payment.reload).to be_refunded
    expect(order.reload).to be_refunded
  end

  it 'finds the refund it already made when the request is repeated' do
    first = record

    expect { expect(record).to eq(first) }.not_to change(BetterTogether::Billing::Refund, :count)
  end

  it 'refuses more than is left to refund' do
    record(amount_cents: 4000, idempotency_key: 'one')

    expect { record(amount_cents: 1000, idempotency_key: 'two') }.to raise_error(described_class::Refused, /refunded/)
  end

  it 'records a processor refund as succeeded, with its reference' do
    refund = record(status: 'succeeded', processor_reference: 're_1')

    expect(refund).to have_attributes(status: 'succeeded', processor_reference: 're_1')
  end
end
