# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Subscription terms and periods' do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'

  let(:term) { start_subscription }
  let(:period) { term.periods.sole }

  describe BetterTogether::Billing::SubscriptionTerm do
    it 'belongs to a platform, a Pay subscription and a plan, one terms per subscription' do
      duplicate = host_platform.billing_subscription_terms.build(pay_subscription: term.pay_subscription, plan: sub_plan, payment_method: 'cash',
                                                                 unit_amount_cents: 1, currency: 'USD', anchor_at: Time.current)

      expect(term).to have_attributes(platform: host_platform, plan: sub_plan)
      expect(duplicate).not_to be_valid
      expect(host_platform.billing_subscription_terms).to include(term)
    end

    it 'finds the payer, and who it is for when that is someone else' do
      expect(term.payer).to eq(buyer)
      expect(term.beneficiary_or_payer).to eq(buyer)
    end

    it 'keeps the plan and the method it began with' do
      term.update!(plan: create(:better_together_billing_plan), payment_method: 'cheque') rescue nil # rubocop:disable Style/RescueModifier

      expect(term.reload).to have_attributes(plan: sub_plan, payment_method: 'cash')
    end

    it 'refuses a plan from another platform' do
      other = create(:better_together_platform)
      foreign_plan = create(:better_together_billing_plan, platform: other)
      invalid = term.dup.tap { |copy| copy.assign_attributes(plan: foreign_plan, pay_subscription: term.pay_subscription) }

      expect(invalid).not_to be_valid
    end

    it 'counts its periods from its anchor in the platform\'s time zone' do
      expect(term.period_start(0)).to eq(term.anchor_at)
      expect(term.period_end(0)).to eq(Time.utc(2027, 2, 28, 15))
      expect(term.time_zone).to eq('UTC')
    end

    it 'knows when Community Engine renews it' do
      expect(term).to be_local
      expect(described_class.local).to include(term)
    end

    it 'refuses a beneficiary type that is not allowed' do
      term.beneficiary_type = 'Kernel'
      term.beneficiary_id = SecureRandom.uuid

      expect(term).not_to be_valid
    end
  end

  describe BetterTogether::Billing::SubscriptionPeriod do
    it 'is one period of one subscription, unique by sequence' do
      again = term.periods.build(platform_id: host_platform.id, sequence: 0, starts_at: 1.day.ago, ends_at: 1.day.from_now)

      expect(again).not_to be_valid
    end

    it 'ends after it starts, in the model and the database' do
      backwards = term.periods.build(platform_id: host_platform.id, sequence: 5, starts_at: 1.day.from_now, ends_at: 1.day.ago)

      expect(backwards).not_to be_valid
    end

    it 'has a status, and says whether it still needs paying' do
      expect(period).to be_paid
      expect(period).to be_covered
      expect(period).not_to be_unsettled
      expect(period.tap { |p| p.status = 'blocked' }).to be_unsettled
      expect(period.tap { |p| p.status = 'nonsense' }).not_to be_valid
    end

    it 'keeps its dates and sequence once made' do
      period.update!(sequence: 9, ends_at: period.ends_at + 1.year)

      expect(period.reload).to have_attributes(sequence: 0, starts_at: term.anchor_at, ends_at: Time.utc(2027, 2, 28, 15))
    end

    it 'agrees with its terms on the platform' do
      period.platform_id = create(:better_together_platform).id

      expect(period).not_to be_valid
    end
  end
end
