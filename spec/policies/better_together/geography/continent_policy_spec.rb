# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::ContinentPolicy, type: :policy do
  let(:user) { create(:better_together_user) }
  let(:continent) { create(:geography_continent, protected: false) }
  let(:protected_continent) { create(:geography_continent, :protected) }

  describe '#index?' do
    it 'allows authenticated user' do
      expect(described_class.new(user, continent).index?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, continent).index?).to be false
    end
  end

  describe '#show?' do
    it 'allows authenticated user' do
      expect(described_class.new(user, continent).show?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, continent).show?).to be false
    end
  end

  describe '#create?' do
    it 'always returns false' do
      expect(described_class.new(user, BetterTogether::Geography::Continent).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows authenticated user for an unprotected continent' do
      expect(described_class.new(user, continent).update?).to be true
    end

    it 'denies authenticated user for a protected continent' do
      expect(described_class.new(user, protected_continent).update?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, continent).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows authenticated user for an unprotected continent' do
      expect(described_class.new(user, continent).destroy?).to be true
    end

    it 'denies authenticated user for a protected continent' do
      expect(described_class.new(user, protected_continent).destroy?).to be false
    end
  end

  describe 'Scope' do
    it 'resolves to continents ordered by identifier' do
      continent
      resolved = described_class::Scope.new(user, BetterTogether::Geography::Continent).resolve
      expect(resolved).to include(continent)
    end
  end
end
