# frozen_string_literal: true

require 'rails_helper'

# A payment made with store credit is refunded to the buyer's credit.
RSpec.describe BetterTogether::Billing::Refunds::Record do # rubocop:disable RSpec/SpecFilePathFormat
  include_context 'with store credit fixtures'

  let!(:soon) { grant_credit(2000, expires_at: 5.days.from_now) }
  let!(:never) { grant_credit(4000) }
  let(:order) { place_with_credit }
  let(:payment) { order.payments.sole }

  def refund(amount, key: 'refund-1', **attrs) = described_class.call(payment:, amount_cents: amount, idempotency_key: key, **attrs)

  it 'puts the money back on the buyer\'s credit, at once' do
    refund = refund(1000, reason: 'requested_by_buyer', recorded_by: steward)

    expect(refund).to have_attributes(status: 'succeeded', amount_cents: 1000, recorded_by: steward)
    expect(account_of.reload.balance_cents).to eq(2000 + 4000 - 4500 + 1000)
    expect(account_of.entries.find_by(kind: 'spend_reversal')).to have_attributes(source: refund, amount_cents: 1000, actor: steward)
    expect(account_of).to be_consistent
  end

  it 'moves the payment and the order, and keeps the Pay charge in step' do
    refund(1000)

    expect(payment.reload).to be_partially_refunded
    expect(order.reload).to be_partially_refunded
    expect(payment.pay_charge.reload.amount_refunded).to eq(1000)
    expect(payment.refunded_cents).to eq(payment.pay_charge.amount_refunded)
  end

  it 'refunds the whole order, returning every cent it took' do
    refund(4500)

    expect(order.reload).to be_refunded
    expect(account_of.reload.balance_cents).to eq(6000)
  end

  it 'refunds in parts that add up, and no more' do
    refund(2000, key: 'one')
    refund(2500, key: 'two')

    expect(account_of.reload.balance_cents).to eq(6000)
    expect { refund(1, key: 'three') }.to raise_error(described_class::Refused, /refunded/)
    expect(account_of.reload.balance_cents).to eq(6000)
  end

  it 'finds the refund it already made when the request is repeated, and gives credit back once' do
    first = refund(1000)

    expect { expect(refund(1000)).to eq(first) }.not_to change(BetterTogether::Billing::CreditEntry, :count)
    expect(account_of.reload.balance_cents).to eq(2500)
  end

  it 'gives credit that has expired meanwhile back as new credit lasting 30 days' do
    payment
    soon.reload.update!(expires_at: 1.minute.ago)

    refund(2000)

    reversal = account_of.entries.find_by(kind: 'spend_reversal')
    expect(reversal.lot).to have_attributes(origin: 'refund')
    expect(reversal.lot.expires_at).to be_within(1.minute).of(30.days.from_now)
  end

  it 'leaves nothing half done when the credit cannot be returned' do
    allow(BetterTogether::Billing::Credit::Reverse).to receive(:call).and_raise(BetterTogether::Billing::Credit::Refused, 'no')

    expect { refund(1000) }.to raise_error(described_class::Refused).and(not_change(BetterTogether::Billing::Refund, :count))
    expect(payment.reload).to be_succeeded
  end
end
