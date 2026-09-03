# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::SettlementPolicy, type: :policy do
  let(:user) { create(:better_together_user) }
  let(:platform_manager) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:settlement) { create(:geography_settlement, protected: false) }
  let(:protected_settlement) { create(:geography_settlement, :protected) }

  describe '#index?' do
    it 'allows authenticated user' do
      expect(described_class.new(user, settlement).index?).to be true
    end

    it 'allows guest — settlements are publicly viewable' do
      expect(described_class.new(nil, settlement).index?).to be true
    end
  end

  describe '#show?' do
    it 'allows guest — settlements are publicly viewable' do
      expect(described_class.new(nil, settlement).show?).to be true
    end
  end

  describe '#create?' do
    it 'always returns false' do
      expect(described_class.new(user, BetterTogether::Geography::Settlement).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows a platform manager for an unprotected settlement' do
      expect(described_class.new(platform_manager, settlement).update?).to be true
    end

    it 'denies an authenticated user without platform-manager permission' do
      expect(described_class.new(user, settlement).update?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, settlement).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows a platform manager for an unprotected settlement' do
      expect(described_class.new(platform_manager, settlement).destroy?).to be true
    end

    it 'denies a platform manager for a protected settlement' do
      expect(described_class.new(platform_manager, protected_settlement).destroy?).to be false
    end

    it 'denies an authenticated user without platform-manager permission' do
      expect(described_class.new(user, settlement).destroy?).to be false
    end
  end
end
