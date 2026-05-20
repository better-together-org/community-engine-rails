# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::C3::Balance do
  subject(:balance) { create(:c3_balance) }

  let(:person)    { create(:better_together_person) }
  let(:recipient) { create(:better_together_person) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:holder) }

    it 'rejects negative available_millitokens' do
      balance.available_millitokens = -1
      expect(balance).not_to be_valid
      expect(balance.errors[:available_millitokens]).to be_present
    end

    it 'rejects negative locked_millitokens' do
      balance.locked_millitokens = -1
      expect(balance).not_to be_valid
    end

    it 'rejects negative lifetime_earned_millitokens' do
      balance.lifetime_earned_millitokens = -1
      expect(balance).not_to be_valid
    end

    it 'accepts zero values for all millitoken columns' do
      expect(balance).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:holder) }
    it { is_expected.to belong_to(:community).optional }
    it { is_expected.to belong_to(:origin_platform).optional }
    it { is_expected.to have_many(:balance_locks).dependent(:destroy) }
  end

  describe '#credit!' do
    it 'increments available_millitokens by the millitoken equivalent' do
      expect { balance.credit!(5.0) }
        .to change { balance.reload.available_millitokens }.by(5_000)
    end

    it 'increments lifetime_earned_millitokens' do
      expect { balance.credit!(5.0) }
        .to change { balance.reload.lifetime_earned_millitokens }.by(5_000)
    end

    it 'accepts fractional C3 amounts' do
      expect { balance.credit!(0.5) }
        .to change { balance.reload.available_millitokens }.by(500)
    end

    it 'does not change locked_millitokens' do
      expect { balance.credit!(5.0) }
        .not_to(change { balance.reload.locked_millitokens })
    end
  end

  describe '#credit_millitokens!' do
    it 'increments available_millitokens by exact amount' do
      expect { balance.credit_millitokens!(3_500) }
        .to change { balance.reload.available_millitokens }.by(3_500)
    end

    it 'increments lifetime_earned_millitokens by exact amount' do
      expect { balance.credit_millitokens!(3_500) }
        .to change { balance.reload.lifetime_earned_millitokens }.by(3_500)
    end

    it 'coerces the argument to integer' do
      expect { balance.credit_millitokens!(1_000.9) }
        .to change { balance.reload.available_millitokens }.by(1_000)
    end
  end

  describe 'C3 reader helpers' do
    before { balance.credit!(7.5) }

    describe '#available_c3' do
      it 'converts available_millitokens to C3 (÷ 1000)' do
        expect(balance.available_c3).to eq(7.5)
      end
    end

    describe '#locked_c3' do
      it 'returns zero when nothing is locked' do
        expect(balance.locked_c3).to eq(0.0)
      end

      it 'reflects locked amount after a lock' do
        balance.lock_c3!(2.0)
        expect(balance.locked_c3).to eq(2.0)
      end
    end

    describe '#lifetime_earned_c3' do
      it 'converts lifetime_earned_millitokens to C3' do
        expect(balance.lifetime_earned_c3).to eq(7.5)
      end

      it 'is not affected by locking' do
        balance.lock_c3!(2.0)
        expect(balance.lifetime_earned_c3).to eq(7.5)
      end
    end
  end

  describe 'BalanceLocking — lock_c3! / lock_millitokens!' do
    before { balance.credit!(10.0) }

    describe '#lock_c3!' do
      it 'decrements available and increments locked by millitoken equivalent' do
        balance.lock_c3!(3.0)
        balance.reload
        expect(balance.available_millitokens).to eq(7_000)
        expect(balance.locked_millitokens).to eq(3_000)
      end

      it 'creates a BalanceLock record and returns its lock_ref UUID' do
        expect { balance.lock_c3!(3.0) }
          .to change(BetterTogether::C3::BalanceLock, :count).by(1)
        lock_ref = balance.lock_c3!(2.0)
        expect(lock_ref).to match(/\A[0-9a-f-]{36}\z/)
      end

      it 'raises InsufficientBalance when amount exceeds available' do
        expect { balance.lock_c3!(11.0) }
          .to raise_error(BetterTogether::C3::Balance::InsufficientBalance)
      end
    end

    describe '#lock_millitokens!' do
      it 'accepts integer millitokens directly' do
        balance.lock_millitokens!(4_000)
        expect(balance.reload.available_millitokens).to eq(6_000)
        expect(balance.reload.locked_millitokens).to eq(4_000)
      end

      it 'raises InsufficientBalance when millitokens exceed available' do
        expect { balance.lock_millitokens!(11_000) }
          .to raise_error(BetterTogether::C3::Balance::InsufficientBalance)
      end
    end
  end

  describe 'BalanceLocking — unlock! / unlock_millitokens!' do
    before do
      balance.credit!(10.0)
      balance.lock_c3!(4.0)
    end

    describe '#unlock_millitokens!' do
      it 'moves millitokens from locked back to available' do
        balance.unlock_millitokens!(2_000)
        balance.reload
        expect(balance.available_millitokens).to eq(8_000)
        expect(balance.locked_millitokens).to eq(2_000)
      end

      it 'raises LockError when amount exceeds locked balance' do
        expect { balance.unlock_millitokens!(5_000) }
          .to raise_error(BetterTogether::C3::Balance::LockError)
      end
    end

    describe '#unlock!' do
      it 'converts C3 amount and moves it from locked to available' do
        balance.unlock!(2.0)
        balance.reload
        expect(balance.available_millitokens).to eq(8_000)
        expect(balance.locked_millitokens).to eq(2_000)
      end

      it 'marks the BalanceLock as released when lock_ref is provided' do
        lock_ref = balance.lock_c3!(1.0)
        balance.unlock!(1.0, lock_ref: lock_ref)
        lock = BetterTogether::C3::BalanceLock.find_by!(lock_ref: lock_ref)
        expect(lock.status).to eq('released')
      end
    end
  end

  describe 'BalanceLocking — settle_to! / settle_to_millitokens!' do
    let(:recipient_balance) { create(:c3_balance) }

    before { balance.credit!(10.0) }

    describe '#settle_to_millitokens!' do
      before { balance.lock_c3!(5.0) }

      it 'debits locked millitokens and credits recipient' do
        balance.settle_to_millitokens!(recipient_balance, 3_000)
        balance.reload
        recipient_balance.reload
        expect(balance.locked_millitokens).to eq(2_000)
        expect(recipient_balance.available_millitokens).to eq(3_000)
        expect(recipient_balance.lifetime_earned_millitokens).to eq(3_000)
      end

      it 'marks the BalanceLock settled when lock_ref is provided' do
        lock_ref = balance.lock_c3!(2.0)
        balance.settle_to_millitokens!(recipient_balance, 2_000, lock_ref: lock_ref)
        lock = BetterTogether::C3::BalanceLock.find_by!(lock_ref: lock_ref)
        expect(lock.status).to eq('settled')
      end

      it 'raises LockError when amount exceeds locked balance' do
        expect { balance.settle_to_millitokens!(recipient_balance, 6_000) }
          .to raise_error(BetterTogether::C3::Balance::LockError)
      end
    end

    describe '#settle_to!' do
      before { balance.lock_c3!(5.0) }

      it 'accepts a C3 amount and settles to recipient' do
        balance.settle_to!(recipient_balance, 3.0)
        expect(recipient_balance.reload.available_millitokens).to eq(3_000)
      end
    end
  end

  describe 'scopes' do
    let!(:local_balance)     { create(:c3_balance) }
    let!(:federated_balance) { create(:c3_balance, :federated) }

    it '.local returns balances without origin_platform' do
      expect(described_class.local).to include(local_balance)
      expect(described_class.local).not_to include(federated_balance)
    end

    it '.federated returns balances with origin_platform' do
      expect(described_class.federated).to include(federated_balance)
      expect(described_class.federated).not_to include(local_balance)
    end
  end
end
