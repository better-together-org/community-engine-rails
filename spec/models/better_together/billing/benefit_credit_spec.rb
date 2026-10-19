# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::BenefitCredit do
  let(:beneficiary) { create(:better_together_community) }
  let(:sponsor) { create(:better_together_person) }

  describe 'validations' do
    subject(:credit) { build(:better_together_billing_benefit_credit, beneficiary:) }

    it 'is valid with a known benefit_key, a nonzero quantity, and a supported beneficiary type' do
      expect(credit).to be_valid
    end

    it 'rejects an unknown benefit_key' do
      credit.benefit_key = 'not_a_real_benefit'

      expect(credit).not_to be_valid
      expect(credit.errors[:benefit_key]).to be_present
    end

    it 'rejects a zero quantity' do
      credit.quantity = 0

      expect(credit).not_to be_valid
      expect(credit.errors[:quantity]).to be_present
    end

    it 'rejects a non-integer quantity' do
      credit.quantity = 1.5

      expect(credit).not_to be_valid
      expect(credit.errors[:quantity]).to be_present
    end

    it 'rejects a beneficiary type that does not include Billing::SponsorshipRecipient' do
      credit.beneficiary = build(:better_together_billing_plan)

      expect(credit).not_to be_valid
      expect(credit.errors[:beneficiary_type]).to be_present
    end

    it 'allows a blank sponsor (self- or admin-granted credit)' do
      credit.sponsor = nil

      expect(credit).to be_valid
    end

    it 'rejects a sponsor type that does not include Billing::Billable' do
      credit.sponsor = build(:better_together_billing_plan)

      expect(credit).not_to be_valid
      expect(credit.errors[:sponsor_type]).to be_present
    end
  end

  describe '.grant!' do
    it 'creates a positive-quantity credit row' do
      credit = described_class.grant!(beneficiary:, benefit_key: 'event_registration', quantity: 3, sponsor:)

      expect(credit).to be_persisted
      expect(credit.quantity).to eq(3)
      expect(credit.sponsor).to eq(sponsor)
    end

    it 'raises for a non-positive quantity argument' do
      expect do
        described_class.grant!(beneficiary:, benefit_key: 'event_registration', quantity: -1)
      end.to raise_error(ArgumentError)
    end
  end

  describe '.available_balance' do
    it 'sums grants and redemptions across mixed histories, never using a stored counter' do
      described_class.grant!(beneficiary:, benefit_key: 'event_registration', quantity: 5)
      described_class.redeem!(beneficiary:, benefit_key: 'event_registration', quantity: 2)
      described_class.grant!(beneficiary:, benefit_key: 'event_registration', quantity: 1)

      expect(described_class.available_balance(beneficiary, 'event_registration')).to eq(4)
    end

    it 'is scoped independently per benefit_key for the same beneficiary' do
      described_class.grant!(beneficiary:, benefit_key: 'event_registration', quantity: 5)

      expect(described_class.available_balance(beneficiary, 'some_other_key')).to eq(0)
    end

    it 'is scoped independently per beneficiary for the same benefit_key' do
      other_beneficiary = create(:better_together_community)
      described_class.grant!(beneficiary:, benefit_key: 'event_registration', quantity: 5)

      expect(described_class.available_balance(other_beneficiary, 'event_registration')).to eq(0)
    end

    it 'returns zero for a beneficiary with no ledger history' do
      expect(described_class.available_balance(beneficiary, 'event_registration')).to eq(0)
    end
  end

  describe '.redeem!' do
    it 'creates a negative-quantity credit row' do
      described_class.grant!(beneficiary:, benefit_key: 'event_registration', quantity: 2)

      credit = described_class.redeem!(beneficiary:, benefit_key: 'event_registration', quantity: 1)

      expect(credit.quantity).to eq(-1)
      expect(described_class.available_balance(beneficiary, 'event_registration')).to eq(1)
    end

    it 'raises InsufficientBalanceError and persists nothing when the balance is too low' do
      described_class.grant!(beneficiary:, benefit_key: 'event_registration', quantity: 1)

      expect do
        described_class.redeem!(beneficiary:, benefit_key: 'event_registration', quantity: 2)
      end.to raise_error(described_class::InsufficientBalanceError)

      expect(described_class.available_balance(beneficiary, 'event_registration')).to eq(1)
    end

    it 'raises for a non-positive quantity argument' do
      expect do
        described_class.redeem!(beneficiary:, benefit_key: 'event_registration', quantity: 0)
      end.to raise_error(ArgumentError)
    end
  end

  describe 'concurrent redemption', :multi_connection do
    it 'allows exactly one of two simultaneous redemptions against a balance of 1 to succeed' do
      described_class.grant!(beneficiary:, benefit_key: 'event_registration', quantity: 1)

      results = []
      results_mutex = Mutex.new
      barrier_mutex = Mutex.new
      barrier_cv = ConditionVariable.new
      arrived = 0

      redeemer = lambda do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier_mutex.synchronize do
            arrived += 1
            arrived >= 2 ? barrier_cv.broadcast : barrier_cv.wait(barrier_mutex)
          end

          begin
            described_class.redeem!(beneficiary:, benefit_key: 'event_registration', quantity: 1)
            results_mutex.synchronize { results << :success }
          rescue described_class::InsufficientBalanceError
            results_mutex.synchronize { results << :failure }
          end
        end
      end

      threads = Array.new(2) { Thread.new(&redeemer) }
      threads.each(&:join)

      expect(results.count(:success)).to eq(1)
      expect(results.count(:failure)).to eq(1)
      expect(described_class.available_balance(beneficiary, 'event_registration')).to eq(0)
    end
  end
end
