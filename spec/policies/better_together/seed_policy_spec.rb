# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SeedPolicy, type: :policy do
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }
  let(:seed) { create(:better_together_seed) }

  describe '#index?' do
    it 'denies guests' do
      expect(described_class.new(nil, BetterTogether::Seed).index?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, BetterTogether::Seed).index?).to be false
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, BetterTogether::Seed).index?).to be true
    end
  end

  describe '#show?' do
    it 'denies guests' do
      expect(described_class.new(nil, seed).show?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, seed).show?).to be false
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, seed).show?).to be true
    end
  end

  describe '#create?' do
    it 'denies guests' do
      expect(described_class.new(nil, BetterTogether::Seed).create?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, BetterTogether::Seed).create?).to be false
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, BetterTogether::Seed).create?).to be true
    end
  end

  describe '#download?' do
    it 'aliases show? — allowed only for managers' do
      expect(described_class.new(manager_user, seed).download?).to be true
      expect(described_class.new(normal_user, seed).download?).to be false
    end
  end

  describe '#destroy?' do
    it 'denies guests' do
      expect(described_class.new(nil, seed).destroy?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, seed).destroy?).to be false
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, seed).destroy?).to be true
    end
  end

  describe 'Scope' do
    let!(:seed) { create(:better_together_seed) }

    it 'returns all seeds for platform managers' do
      resolved = described_class::Scope.new(manager_user, BetterTogether::Seed).resolve
      expect(resolved).to include(seed)
    end

    it 'returns none for non-managers' do
      resolved = described_class::Scope.new(normal_user, BetterTogether::Seed).resolve
      expect(resolved).to be_empty
    end

    it 'returns none for guests' do
      resolved = described_class::Scope.new(nil, BetterTogether::Seed).resolve
      expect(resolved).to be_empty
    end
  end
end
