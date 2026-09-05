# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe BetterTogether::Geography::RegionSettlementPolicy, type: :policy do
  let(:user) { create(:better_together_user) }
  let(:record) { double('region_settlement', protected?: false) }
  let(:protected_record) { double('region_settlement_protected', protected?: true) }

  describe '#index?' do
    it 'allows authenticated user' do
      expect(described_class.new(user, record).index?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, record).index?).to be false
    end
  end

  describe '#create?' do
    it 'always returns false' do
      expect(described_class.new(user, BetterTogether::Geography::RegionSettlement).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows authenticated user for an unprotected record' do
      expect(described_class.new(user, record).update?).to be true
    end

    it 'denies authenticated user for a protected record' do
      expect(described_class.new(user, protected_record).update?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, record).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows authenticated user for an unprotected record' do
      expect(described_class.new(user, record).destroy?).to be true
    end

    it 'denies authenticated user for a protected record' do
      expect(described_class.new(user, protected_record).destroy?).to be false
    end
  end

  describe 'Scope' do
    it 'resolves to all records' do
      resolved = described_class::Scope.new(user, BetterTogether::Geography::RegionSettlement).resolve
      expect(resolved.to_sql).to include('region_settlements')
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
