# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::SettlementPolicy, type: :policy do
  let(:user) { create(:better_together_user) }
  let(:settlement) { create(:geography_settlement, protected: false) }
  let(:protected_settlement) { create(:geography_settlement, :protected) }

  describe '#index?' do
    it 'allows authenticated user' do
      expect(described_class.new(user, settlement).index?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, settlement).index?).to be false
    end
  end

  describe '#create?' do
    it 'always returns false' do
      expect(described_class.new(user, BetterTogether::Geography::Settlement).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows authenticated user for an unprotected settlement' do
      expect(described_class.new(user, settlement).update?).to be true
    end

    it 'denies authenticated user for a protected settlement' do
      expect(described_class.new(user, protected_settlement).update?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, settlement).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows authenticated user for an unprotected settlement' do
      expect(described_class.new(user, settlement).destroy?).to be true
    end

    it 'denies authenticated user for a protected settlement' do
      expect(described_class.new(user, protected_settlement).destroy?).to be false
    end
  end
end
