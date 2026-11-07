# frozen_string_literal: true

require 'rails_helper'

# A renewal invoice is paid, and the Pay subscription moves on.
RSpec.describe BetterTogether::Billing::Subscriptions::OrderPaid do
  include_context 'with subscription fixtures'

  let(:term) { start_subscription }
  let(:invoice_time) { Time.utc(2027, 2, 20, 8) }

  def subscription = term.reload.pay_subscription

  before { generate_renewal(term, at: invoice_time) }

  it 'moves the subscription to the next period when the invoice is paid in time' do
    pay_renewal(term, at: Time.utc(2027, 2, 25, 9))

    expect(term.periods.last).to have_attributes(sequence: 1, status: 'paid')
    expect(subscription).to have_attributes(status: 'active', current_period_start: Time.utc(2027, 2, 28, 15),
                                            current_period_end: Time.utc(2027, 3, 31, 15), ends_at: nil)
  end

  it 'covers the next period as soon as it is paid, even long before the old one ends' do
    pay_renewal(term, at: Time.utc(2027, 2, 15, 9))

    expect(subscription.current_period_end).to eq(Time.utc(2027, 3, 31, 15))
  end

  it 'runs on from the old end when paid inside the grace, not from the day of payment' do
    advance(term, at: Time.utc(2027, 3, 2))
    expect(subscription).to be_past_due

    pay_renewal(term, at: Time.utc(2027, 3, 4, 9))

    expect(subscription).to have_attributes(status: 'active', current_period_end: Time.utc(2027, 3, 31, 15))
    expect(term.reload.grace_ends_at).to be_nil
  end

  it 'counts a cheque posted in time and confirmed late: the day it arrived decides' do
    advance(term, at: Time.utc(2027, 3, 12)) # grace over (Mar 7): lapsed
    expect(subscription.status).to eq('unpaid')

    pay_renewal(term, at: Time.utc(2027, 3, 12, 9), received_on: Date.new(2027, 3, 5))

    expect(subscription).to have_attributes(status: 'active', current_period_end: Time.utc(2027, 3, 31, 15), ends_at: nil)
  end

  it 'starts again from the day it was paid, nothing back-dated, when paid after the subscription lapsed' do
    advance(term, at: Time.utc(2027, 3, 12))
    expect(subscription.status).to eq('unpaid')

    pay_renewal(term, at: Time.utc(2027, 3, 20, 10))

    expect(subscription).to have_attributes(status: 'active', ends_at: nil, current_period_start: Time.utc(2027, 3, 20, 10),
                                            current_period_end: Time.utc(2027, 4, 20, 10))
    expect(term.reload).to have_attributes(anchor_at: Time.utc(2027, 3, 20, 10), anchor_sequence: 1, grace_ends_at: nil)
    expect(term.period_end(1)).to eq(Time.utc(2027, 4, 20, 10))
  end

  it 'makes the invoice after that one from the new anchor, with no drift' do
    advance(term, at: Time.utc(2027, 3, 12))
    pay_renewal(term, at: Time.utc(2027, 3, 31, 10))

    period = generate_renewal(term, at: Time.utc(2027, 4, 20))

    expect(period).to have_attributes(sequence: 2, starts_at: Time.utc(2027, 4, 30, 10), ends_at: Time.utc(2027, 5, 31, 10))
  end

  it 'is done once however often it runs' do
    pay_renewal(term, at: Time.utc(2027, 2, 25, 9))
    order = term.periods.last.order

    expect { described_class.call(order) }.not_to(change { subscription.reload.current_period_end })
  end

  it 'leaves a subscription that was ended on purpose ended' do
    BetterTogether::Billing::Subscriptions::Cancel.call(term: term.reload, now: true)

    pay_renewal(term, at: Time.utc(2027, 2, 25, 9)) if term.periods.last.order&.open?

    expect(subscription.status).to eq('canceled')
  end
end
