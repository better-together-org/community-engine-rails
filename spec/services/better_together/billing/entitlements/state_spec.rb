# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Entitlements::State do
  let(:now) { Time.utc(2027, 3, 1, 12) }
  let(:period_end) { Time.utc(2027, 3, 15, 12) }
  let(:term) { instance_double(BetterTogether::Billing::SubscriptionTerm, grace_ends_at: Time.utc(2027, 3, 20, 12)) }

  def subscription(**attrs)
    Pay::Subscription.new({ status: 'active', current_period_end: period_end, ends_at: nil, trial_ends_at: nil }.merge(attrs))
  end

  def result(**attrs) = described_class.call(subscription(**attrs), term, now:)

  it 'gives something for every status Pay has, and refuses one it does not know' do
    described_class::STATUSES.each { |status| expect { result(status:) }.not_to raise_error }
    expect { result(status: 'martian') }.to raise_error(ArgumentError)
  end

  it 'is active until the period ends for an active or trialing subscription' do
    %w[active trialing].each do |status|
      expect(result(status:)).to have_attributes(status: 'active', ends_at: period_end, grace_ends_at: nil)
    end
  end

  it 'is active until a trial ends while on one' do
    trial_end = Time.utc(2027, 3, 8, 12)

    expect(result(status: 'trialing', trial_ends_at: trial_end).ends_at).to eq(trial_end)
  end

  it 'keeps access to the end date of a subscription cancelled at the end of its period' do
    expect(result(ends_at: period_end)).to have_attributes(status: 'active', ends_at: period_end)
  end

  it 'has lapsed once an end date has passed, however the status reads' do
    expect(result(ends_at: now - 1.hour)).to have_attributes(status: 'lapsed')
  end

  it 'is in grace while past due, until the terms\' grace ends, then lapsed' do
    expect(result(status: 'past_due')).to have_attributes(status: 'grace', grace_ends_at: Time.utc(2027, 3, 20, 12), ends_at: period_end)
    expect(described_class.call(subscription(status: 'past_due'), term, now: Time.utc(2027, 3, 21))).to have_attributes(status: 'lapsed')
  end

  it 'falls back to the end of the period for the grace when there are no terms (a processor\'s subscription)' do
    expect(described_class.call(subscription(status: 'past_due'), nil, now:)).to have_attributes(status: 'grace', grace_ends_at: period_end)
  end

  it 'has lapsed for every status that means it is not being paid' do
    %w[unpaid canceled incomplete_expired paused].each { |status| expect(result(status:)).to have_attributes(status: 'lapsed') }
  end

  it 'is pending, with nothing given yet, while incomplete' do
    expect(result(status: 'incomplete')).to have_attributes(status: 'pending')
    expect(result(status: 'incomplete')).not_to be_live
  end

  it 'is live only while active or in grace' do
    expect(result).to be_live
    expect(result(status: 'past_due')).to be_live
    expect(result(status: 'unpaid')).not_to be_live
  end
end
