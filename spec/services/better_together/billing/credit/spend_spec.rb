# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Credit::Spend do
  include_context 'with store credit fixtures'

  let(:order) { place_order }
  let(:payment) { create(:better_together_billing_payment, order:, amount_cents: 4500, processor: 'store_credit') }

  def spend(amount, key: 'spend-1', purpose: 'one_time', **attrs)
    described_class.call(account: account_of, amount_cents: amount, purpose:, source: payment, idempotency_key: key, **attrs)
  end

  it 'takes the credit that expires soonest first, then the oldest, one entry per lot' do
    never = grant_credit(1000)
    late = grant_credit(1000, expires_at: 30.days.from_now)
    soon = grant_credit(1000, expires_at: 3.days.from_now)

    entries = spend(1500)

    expect(entries.map { |entry| [entry.lot, entry.amount_cents] }).to eq([[soon, -1000], [late, -500]])
    expect([soon, late, never].map { |lot| lot.reload.remaining_cents }).to eq([0, 500, 1000])
    expect(account_of.reload).to have_attributes(balance_cents: 1500)
    expect(account_of).to be_consistent
  end

  it 'records the balance after each entry and what it was spent on' do
    grant_credit(1000)

    entry = spend(400).sole

    expect(entry).to have_attributes(kind: 'spend', amount_cents: -400, balance_after_cents: 600, source: payment)
  end

  it 'spends all of it or none' do
    grant_credit(1000)

    expect { spend(1001) }.to raise_error(BetterTogether::Billing::Credit::Refused, /not enough/)

    expect(account_of.reload.balance_cents).to eq(1000)
    expect(account_of.entries.spends).to be_empty
  end

  it 'does not touch credit that has expired or is kept for another kind of purchase' do
    grant_credit(1000, expires_at: 1.day.ago)
    grant_credit(1000, purposes: %w[ticket])
    grant_credit(200)

    expect { spend(300) }.to raise_error(BetterTogether::Billing::Credit::Refused)
    expect(spend(200).sole.amount_cents).to eq(-200)
    expect(account_of.usable_cents(purpose: 'ticket')).to eq(1000)
  end

  it 'finds what it already spent when the request is repeated' do
    grant_credit(1000)
    first = spend(400)

    expect { expect(spend(400)).to eq(first) }.not_to change(BetterTogether::Billing::CreditEntry, :count)
    expect(account_of.reload.balance_cents).to eq(600)
  end

  it 'refuses nothing' do
    grant_credit(1000)

    expect { spend(0) }.to raise_error(BetterTogether::Billing::Credit::Refused)
  end

  it 'cannot overspend when a second request holds an out-of-date copy of the account' do
    grant_credit(1000)
    stale = BetterTogether::Billing::CreditAccount.find(account_of.id)
    spend(700)

    expect do
      described_class.call(account: stale, amount_cents: 700, purpose: 'one_time', source: payment, idempotency_key: 'second')
    end.to raise_error(BetterTogether::Billing::Credit::Refused)
    expect(account_of.reload.balance_cents).to eq(300)
  end
end
