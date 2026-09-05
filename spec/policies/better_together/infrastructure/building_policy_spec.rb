# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Infrastructure::BuildingPolicy, type: :policy do
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user) { create(:better_together_user, person: creator_person) }
  let(:normal_user) { create(:better_together_user) }

  # rubocop:disable RSpec/VerifiedDoubles
  let(:unprotected_building) { double('building', creator: creator_person, protected?: false) }
  let(:protected_building) { double('building', creator: creator_person, protected?: true) }
  # rubocop:enable RSpec/VerifiedDoubles

  describe '#index?' do
    it 'allows authenticated user' do
      expect(described_class.new(normal_user, unprotected_building).index?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, unprotected_building).index?).to be false
    end
  end

  describe '#show?' do
    it 'allows authenticated user' do
      expect(described_class.new(normal_user, unprotected_building).show?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, unprotected_building).show?).to be false
    end
  end

  describe '#create?' do
    it 'allows authenticated user' do
      expect(described_class.new(normal_user, BetterTogether::Infrastructure::Building).create?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, BetterTogether::Infrastructure::Building).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows creator of an unprotected building' do
      expect(described_class.new(creator_user, unprotected_building).update?).to be true
    end

    it 'denies creator of a protected building' do
      expect(described_class.new(creator_user, protected_building).update?).to be false
    end

    it 'denies another user' do
      expect(described_class.new(normal_user, unprotected_building).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows creator of an unprotected building' do
      expect(described_class.new(creator_user, unprotected_building).destroy?).to be true
    end

    it 'denies creator of a protected building' do
      expect(described_class.new(creator_user, protected_building).destroy?).to be false
    end

    it 'denies another user' do
      expect(described_class.new(normal_user, unprotected_building).destroy?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, unprotected_building).destroy?).to be false
    end
  end
end
