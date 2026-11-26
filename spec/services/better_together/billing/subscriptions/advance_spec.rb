# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Subscriptions::Advance do
  include_context 'with subscription fixtures'

  let(:term) { start_subscription }
  let(:period_end) { Time.utc(2027, 2, 28, 15) }

  def subscription = term.reload.pay_subscription

  it 'leaves a subscription whose period has not ended' do
    advance(term, at: period_end - 1.hour)

    expect(subscription.status).to eq('active')
  end

  it 'moves it to past due when the period ends unpaid, with the grace running from that moment' do
    advance(term, at: period_end + 1.hour)

    expect(subscription).to have_attributes(status: 'past_due', ends_at: nil)
    expect(term.reload.grace_ends_at).to eq(period_end + 7.days)
  end

  it 'tells the payer and the stewards it is overdue, once' do
    clear_notices
    deliver_now do
      advance(term, at: period_end + 1.hour)
      advance(term, at: period_end + 2.hours)
    end

    expect(kinds_for(buyer).count('renewal_overdue')).to eq(1)
  end

  it 'lapses it when the grace ends: unpaid, ending where the grace ended, the period lapsed' do
    generate_renewal(term, at: Time.utc(2027, 2, 20))
    advance(term, at: period_end + 1.hour)
    advance(term, at: period_end + 7.days + 1.minute)

    expect(subscription).to have_attributes(status: 'unpaid', ends_at: period_end + 7.days)
    expect(term.periods.last).to be_lapsed
  end

  it 'lapses at once when the plan gives no grace' do
    sub_plan.update_columns(grace_days: 0) # rubocop:disable Rails/SkipsModelValidations

    advance(term, at: period_end + 1.hour)

    expect(subscription.status).to eq('unpaid')
  end

  it 'never deletes anything when it lapses: the invoice stays open to be paid later' do
    generate_renewal(term, at: Time.utc(2027, 2, 20))
    advance(term, at: period_end + 8.days)

    expect(term.periods.last.order).to be_open
    expect(term.pay_subscription.customer).to be_present
  end

  it 'ends a subscription cancelled at the end of its period once that moment passes' do
    BetterTogether::Billing::Subscriptions::Cancel.call(term:)

    advance(term, at: period_end - 1.hour)
    expect(subscription).to have_attributes(status: 'active')
    advance(term, at: period_end + 1.hour)

    expect(subscription.status).to eq('canceled')
  end

  it 'steps through once each however often it runs' do
    3.times { advance(term, at: period_end + 8.days) }

    expect(subscription).to have_attributes(status: 'unpaid', ends_at: period_end + 7.days)
  end
end
