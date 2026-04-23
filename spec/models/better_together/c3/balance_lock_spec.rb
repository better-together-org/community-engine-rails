# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::C3::BalanceLock do
  let(:person)  { create(:better_together_person) }
  let(:balance) do
    BetterTogether::C3::Balance.find_or_create_by!(holder: person).tap { |b| b.credit!(10.0) }
  end
  let(:lock_ref) { balance.lock!(3.0, agreement_ref: 'test-agreement') }
  let(:lock)     { described_class.find_by!(lock_ref: lock_ref) }

  describe 'creation via Balance#lock!' do
    it 'creates a pending BalanceLock with a lock_ref' do
      expect(lock.status).to eq('pending')
      expect(lock.lock_ref).to be_present
      expect(lock.millitokens).to eq(30_000)
    end

    it 'sets expires_at to 24 hours from now by default' do
      expect(lock.expires_at).to be_within(5.seconds).of(described_class::DEFAULT_TTL.from_now)
    end

    it 'returns the lock_ref UUID from Balance#lock!' do
      expect(lock_ref).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe 'validations' do
    it 'requires lock_ref uniqueness' do
      duplicate = described_class.new(
        balance: balance,
        lock_ref: lock_ref,
        millitokens: 10_000,
        expires_at: 1.hour.from_now,
        status: 'pending'
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:lock_ref]).to be_present
    end

    it 'rejects millitokens above MAX_SINGLE_TRANSACTION_MILLITOKENS' do
      bad_lock = described_class.new(
        balance: balance,
        lock_ref: SecureRandom.uuid,
        millitokens: BetterTogether::C3::Token::MAX_SINGLE_TRANSACTION_MILLITOKENS + 1,
        expires_at: 1.hour.from_now,
        status: 'pending'
      )
      expect(bad_lock).not_to be_valid
    end

    it 'rejects zero millitokens' do
      bad_lock = described_class.new(
        balance: balance,
        lock_ref: SecureRandom.uuid,
        millitokens: 0,
        expires_at: 1.hour.from_now,
        status: 'pending'
      )
      expect(bad_lock).not_to be_valid
    end
  end

  describe '#settle!' do
    it 'transitions to settled and sets settled_at' do
      lock.settle!
      expect(lock.reload.status).to eq('settled')
      expect(lock.settled_at).to be_present
    end
  end

  describe '#release!' do
    it 'transitions to released and sets settled_at' do
      lock.release!
      expect(lock.reload.status).to eq('released')
      expect(lock.settled_at).to be_present
    end
  end

  describe '#expire!' do
    it 'releases the C3 back to the balance and marks expired' do
      available_before = balance.reload.available_millitokens
      lock.expire!
      expect(lock.reload.status).to eq('expired')
      expect(balance.reload.available_millitokens).to eq(available_before + 30_000)
    end

    it 'is a no-op when already settled' do
      lock.settle!
      expect { lock.expire! }.not_to(change { balance.reload.available_millitokens })
    end
  end

  describe 'scopes' do
    it '.pending returns only pending locks' do
      lock # trigger creation
      expect(described_class.pending).to include(lock)
    end

    it '.expired returns pending locks past expires_at' do
      lock.update_columns(expires_at: 1.hour.ago)
      expect(described_class.expired).to include(lock)
    end

    it '.expired excludes future locks' do
      lock # default 24h expiry
      expect(described_class.expired).not_to include(lock)
    end

    it '.active returns pending locks with future expires_at' do
      lock
      expect(described_class.active).to include(lock)
    end
  end
end
