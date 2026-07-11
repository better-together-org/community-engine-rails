# frozen_string_literal: true

require 'rails_helper'

# BalanceLocking is a concern included in C3::Balance.
# These specs exercise the concern's behaviour through Balance directly.
RSpec.describe BetterTogether::C3::BalanceLocking do
  let(:person) { create(:better_together_person) }

  let(:balance) do
    create(:c3_balance, holder: person, available_millitokens: 5_000, locked_millitokens: 0)
  end

  it 'is included in C3::Balance' do
    expect(BetterTogether::C3::Balance.ancestors).to include(described_class)
  end

  it 'defines MILLITOKEN_SCALE matching Token::MILLITOKEN_SCALE' do
    expect(described_class::MILLITOKEN_SCALE).to eq(BetterTogether::C3::Token::MILLITOKEN_SCALE)
  end

  describe '#lock_millitokens!' do
    it 'decrements available and increments locked by the requested amount' do
      balance.lock_millitokens!(1_000)
      balance.reload
      expect(balance.available_millitokens).to eq(4_000)
      expect(balance.locked_millitokens).to eq(1_000)
    end

    it 'returns a lock_ref string' do
      ref = balance.lock_millitokens!(500)
      expect(ref).to be_a(String).and be_present
    end

    it 'raises InsufficientBalance when amount exceeds available' do
      expect do
        balance.lock_millitokens!(6_000)
      end.to raise_error(BetterTogether::C3::Balance::InsufficientBalance)
    end
  end

  describe '#unlock_millitokens!' do
    before { balance.lock_millitokens!(1_000) }

    it 'increments available and decrements locked' do
      balance.unlock_millitokens!(1_000)
      balance.reload
      expect(balance.available_millitokens).to eq(5_000)
      expect(balance.locked_millitokens).to eq(0)
    end

    it 'raises LockError when amount exceeds locked balance' do
      expect do
        balance.unlock_millitokens!(2_000)
      end.to raise_error(BetterTogether::C3::Balance::LockError)
    end
  end

  describe 'locked_millitokens validation' do
    it 'rejects negative locked_millitokens' do
      balance.locked_millitokens = -1
      expect(balance).not_to be_valid
    end
  end
end
