# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::RegionPolicy, type: :policy do
  let(:user) { create(:better_together_user) }
  let(:region) { create(:geography_region, protected: false) }
  let(:protected_region) { create(:geography_region, :protected) }

  describe '#index?' do
    it 'allows authenticated user' do
      expect(described_class.new(user, region).index?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, region).index?).to be false
    end
  end

  describe '#create?' do
    it 'always returns false' do
      expect(described_class.new(user, BetterTogether::Geography::Region).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows authenticated user for an unprotected region' do
      expect(described_class.new(user, region).update?).to be true
    end

    it 'denies authenticated user for a protected region' do
      expect(described_class.new(user, protected_region).update?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, region).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows authenticated user for an unprotected region' do
      expect(described_class.new(user, region).destroy?).to be true
    end

    it 'denies authenticated user for a protected region' do
      expect(described_class.new(user, protected_region).destroy?).to be false
    end
  end
end
