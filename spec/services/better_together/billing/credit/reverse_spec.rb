# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Credit::Reverse do
  include_context 'with store credit fixtures'

  let(:order) { place_order }
  let(:payment) { create(:better_together_billing_payment, order:, amount_cents: 1500, processor: 'store_credit') }
  let!(:soon) { grant_credit(1000, expires_at: 3.days.from_now) }
  let!(:never) { grant_credit(1000) }

  before do
    BetterTogether::Billing::Credit::Spend.call(account: account_of, amount_cents: 1500, purpose: 'one_time', source: payment,
                                                idempotency_key: 'spend')
  end

  def reverse(amount, key: 'reverse-1', **attrs)
    described_class.call(payment:, amount_cents: amount, idempotency_key: key, **attrs)
  end

  it 'gives credit back to the lot it came from, as a reversal of that spend' do
    entries = reverse(700)

    expect(entries.map { |entry| [entry.lot, entry.amount_cents] }).to eq([[soon, 700]])
    expect(entries.sole.reverses_entry).to have_attributes(kind: 'spend', amount_cents: -1000)
    expect(soon.reload.remaining_cents).to eq(700)
    expect(account_of.reload.balance_cents).to eq(1200)
    expect(account_of).to be_consistent
  end

  it 'works through the spends in the order they were made and never gives back more than was taken' do
    entries = reverse(1500)

    expect(entries.map { |entry| [entry.lot, entry.amount_cents] }).to eq([[soon, 1000], [never, 500]])
    expect { reverse(1, key: 'reverse-2') }.to raise_error(BetterTogether::Billing::Credit::Refused, /more than was spent/)
    expect(account_of.reload.balance_cents).to eq(2000)
  end

  it 'counts what was already given back' do
    reverse(900)

    expect(reverse(600, key: 'reverse-2').map(&:amount_cents)).to eq([100, 500])
    expect { reverse(1, key: 'reverse-3') }.to raise_error(BetterTogether::Billing::Credit::Refused)
  end

  it 'gives a lot that has expired meanwhile back as new credit that lasts 30 days, so a refund never extends a promotion' do
    soon.reload.update!(expires_at: 1.day.ago)

    entry = reverse(400).sole

    expect(entry.lot).not_to eq(soon)
    expect(entry.lot).to have_attributes(origin: 'refund', amount_cents: 400, remaining_cents: 400)
    expect(entry.lot.expires_at).to be_within(1.minute).of(30.days.from_now)
    expect(soon.reload.remaining_cents).to eq(0)
    expect(account_of.reload).to be_consistent
  end

  it 'finds what it already gave back when the request is repeated' do
    first = reverse(700)

    expect { expect(reverse(700)).to eq(first) }.not_to change(BetterTogether::Billing::CreditEntry, :count)
  end

  it 'refuses a payment that credit never paid for' do
    other = create(:better_together_billing_payment, order: place_order, amount_cents: 100)

    expect { described_class.call(payment: other, amount_cents: 100, idempotency_key: 'x') }
      .to raise_error(BetterTogether::Billing::Credit::Refused, /no credit was spent/)
  end
end
