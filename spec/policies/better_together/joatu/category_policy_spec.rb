# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::CategoryPolicy, type: :policy do
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }
  let(:category) { create(:better_together_joatu_category) }

  describe '#index?' do
    it 'denies guests' do
      expect(described_class.new(nil, BetterTogether::Joatu::Category).index?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, BetterTogether::Joatu::Category).index?).to be false
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, BetterTogether::Joatu::Category).index?).to be true
    end
  end

  describe '#show?' do
    it 'denies guests' do
      expect(described_class.new(nil, category).show?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, category).show?).to be false
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, category).show?).to be true
    end
  end

  describe '#create?' do
    it 'denies guests' do
      expect(described_class.new(nil, BetterTogether::Joatu::Category).create?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, BetterTogether::Joatu::Category).create?).to be false
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, BetterTogether::Joatu::Category).create?).to be true
    end
  end

  describe 'Scope' do
    let!(:category) { create(:better_together_joatu_category) }

    it 'returns all categories for platform managers' do
      resolved = described_class::Scope.new(manager_user, BetterTogether::Joatu::Category).resolve
      expect(resolved).to include(category)
    end

    it 'returns none for non-managers' do
      resolved = described_class::Scope.new(normal_user, BetterTogether::Joatu::Category).resolve
      expect(resolved).to be_empty
    end

    it 'returns none for guests' do
      resolved = described_class::Scope.new(nil, BetterTogether::Joatu::Category).resolve
      expect(resolved).to be_empty
    end
  end
end
