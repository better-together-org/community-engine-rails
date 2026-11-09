# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Periods do
  def plan(interval: 'month', count: 1) = build_stubbed(:better_together_billing_plan, billing_interval: interval, interval_count: count)

  def starts(anchor, sequence, **) = described_class.starts_at(anchor:, plan: plan, sequence:, **)

  it 'counts every period from the anchor, so a month-end start never drifts' do
    anchor = Time.utc(2027, 1, 31, 15)

    expect((0..4).map { |n| starts(anchor, n).to_date.to_s }).to eq(%w[2027-01-31 2027-02-28 2027-03-31 2027-04-30 2027-05-31])
  end

  it 'clamps to the last day in a leap year, then returns to the anchor day' do
    anchor = Time.utc(2028, 1, 31, 15)

    expect([1, 2].map { |n| starts(anchor, n).to_date.to_s }).to eq(%w[2028-02-29 2028-03-31])
  end

  it 'ends a period where the next begins' do
    anchor = Time.utc(2027, 1, 31, 15)

    expect(described_class.ends_at(anchor:, plan:, sequence: 0)).to eq(starts(anchor, 1))
  end

  it 'counts a yearly plan in years, and a plan of several intervals in that many months' do
    anchor = Time.utc(2027, 2, 28, 12)

    expect(described_class.starts_at(anchor:, plan: plan(interval: 'year'), sequence: 1)).to eq(Time.utc(2028, 2, 28, 12))
    expect(described_class.starts_at(anchor:, plan: plan(count: 3), sequence: 2)).to eq(Time.utc(2027, 8, 28, 12))
    expect(described_class.months(plan(interval: 'year', count: 2))).to eq(24)
  end

  it 'keeps the local time across a daylight saving change by counting in the platform\'s zone' do
    anchor = Time.utc(2027, 3, 1, 14) # 9 a.m. in Toronto, before the change on March 14

    renewal = starts(anchor, 1, time_zone: 'America/Toronto')

    expect(renewal).to eq(Time.utc(2027, 4, 1, 13)) # still 9 a.m., now daylight time
    expect(starts(anchor, 1, time_zone: 'UTC')).to eq(Time.utc(2027, 4, 1, 14))
  end

  it 'starts counting from a later period when the subscription started again' do
    anchor = Time.utc(2027, 6, 10, 9)

    expect(starts(anchor, 4, anchor_sequence: 4)).to eq(anchor)
    expect(starts(anchor, 5, anchor_sequence: 4)).to eq(Time.utc(2027, 7, 10, 9))
  end

  it 'has no periods for a plan that is paid once' do
    expect { described_class.starts_at(anchor: Time.current, plan: plan(interval: 'one_time'), sequence: 1) }.to raise_error(ArgumentError)
  end
end
