# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::MapPolicy, type: :policy do
  let(:steward_user) { create(:better_together_user, :platform_steward) }
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user) { create(:better_together_user, person: creator_person) }
  let(:normal_user) { create(:better_together_user) }
  let(:map) { create(:geography_map, creator: creator_person, protected: false) }
  let(:protected_map) { create(:geography_map, creator: creator_person, protected: true) }

  describe '#index?' do
    it 'allows platform steward (map manager)' do
      expect(described_class.new(steward_user, map).index?).to be true
    end

    it 'denies normal user without map manager permission' do
      expect(described_class.new(normal_user, map).index?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, map).index?).to be false
    end
  end

  describe '#show?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, map).show?).to be true
    end

    it 'allows platform steward' do
      expect(described_class.new(steward_user, map).show?).to be true
    end

    it 'denies another user' do
      expect(described_class.new(normal_user, map).show?).to be false
    end
  end

  describe '#create?' do
    it 'allows platform steward' do
      expect(described_class.new(steward_user, BetterTogether::Geography::Map).create?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, BetterTogether::Geography::Map).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, map).update?).to be true
    end

    it 'allows platform steward' do
      expect(described_class.new(steward_user, map).update?).to be true
    end

    it 'denies another user' do
      expect(described_class.new(normal_user, map).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows the creator of an unprotected map' do
      expect(described_class.new(creator_user, map).destroy?).to be true
    end

    it 'denies destruction of a protected map' do
      expect(described_class.new(steward_user, protected_map).destroy?).to be false
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, map).destroy?).to be false
    end
  end
end
