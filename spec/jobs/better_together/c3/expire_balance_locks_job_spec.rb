# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::C3::ExpireBalanceLocksJob do
  include ActiveJob::TestHelper

  subject(:job) { described_class.new }

  # Helper: create a BalanceLock record directly, bypassing BetterTogether::C3::BalanceLocking#lock!
  # which conflicts with ActiveRecord::Locking::Pessimistic#lock! causing BigDecimal errors.
  def create_pending_lock(c3_balance, millitokens:, expired: false)
    expires_at = expired ? 2.hours.ago : 2.hours.from_now
    c3_balance.update_columns(
      available_millitokens: c3_balance.available_millitokens - millitokens,
      locked_millitokens: c3_balance.locked_millitokens + millitokens
    )
    BetterTogether::C3::BalanceLock.create!(
      balance: c3_balance,
      lock_ref: SecureRandom.uuid,
      millitokens: millitokens,
      expires_at: expires_at,
      status: 'pending'
    )
  end

  describe 'queue configuration' do
    it 'uses the default queue' do
      expect(described_class.queue_name).to eq('default')
    end
  end

  describe '#perform' do
    let(:person) { create(:better_together_person) }
    let(:c3_balance) do
      BetterTogether::C3::Balance.find_or_create_by!(holder: person).tap do |b|
        b.update_columns(available_millitokens: 10_000, lifetime_earned_millitokens: 10_000)
      end
    end

    # A lock that is already past its expires_at — matched by the .expired scope.
    let!(:expired_lock)  { create_pending_lock(c3_balance, millitokens: 3_000, expired: true) }

    # A lock still within TTL — must NOT be touched by the job.
    let!(:active_lock)   { create_pending_lock(c3_balance, millitokens: 1_000, expired: false) }

    it 'transitions expired locks to status "expired"' do
      job.perform
      expect(expired_lock.reload.status).to eq('expired')
    end

    it 'releases the locked C3 back to the balance for expired locks' do
      available_before = c3_balance.reload.available_millitokens
      job.perform
      expect(c3_balance.reload.available_millitokens).to eq(available_before + 3_000)
    end

    it 'does not alter active (non-expired) locks' do
      job.perform
      expect(active_lock.reload.status).to eq('pending')
    end

    it 'continues processing remaining locks when one raises a StandardError' do
      # A second expired lock (will be processed normally)
      lock2 = create_pending_lock(c3_balance, millitokens: 2_000, expired: true)

      # Make the FIRST expired lock raise on expire! — the job must continue to lock2.
      # We stub the instance directly after fetching; the real .expired scope returns
      # an ActiveRecord::Relation (required for find_each), so we leave the scope alone
      # and instead intercept expire! on the specific record.
      allow(expired_lock).to receive(:expire!).and_raise(StandardError, 'simulated failure')

      # Stub find_each on the relation to yield our controlled locks in order
      real_expired_relation = BetterTogether::C3::BalanceLock.expired
      allow(BetterTogether::C3::BalanceLock).to receive(:expired).and_return(real_expired_relation)
      allow(real_expired_relation).to receive(:find_each).and_yield(expired_lock).and_yield(lock2)

      expect(Rails.logger).to receive(:error).with(/simulated failure/)

      expect { job.perform }.not_to raise_error
      expect(lock2.reload.status).to eq('expired')
    end
  end
end
