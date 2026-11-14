# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::NavigationAreaPolicy, type: :policy do
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }
  let(:nav_area) { create(:better_together_navigation_area, protected: false) }
  let(:protected_area) { create(:better_together_navigation_area, protected: true) }

  describe '#index?' do
    it 'allows guests' do
      expect(described_class.new(nil, nav_area).index?).to be true
    end

    it 'allows authenticated users' do
      expect(described_class.new(normal_user, nav_area).index?).to be true
    end
  end

  describe '#show?' do
    it 'allows guests' do
      expect(described_class.new(nil, nav_area).show?).to be true
    end

    it 'allows authenticated users' do
      expect(described_class.new(normal_user, nav_area).show?).to be true
    end
  end

  describe '#create?' do
    it 'denies guests' do
      expect(described_class.new(nil, nav_area).create?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, nav_area).create?).to be false
    end

    it 'allows platform navigation managers' do
      expect(described_class.new(manager_user, nav_area).create?).to be true
    end
  end

  describe '#update?' do
    it 'denies guests' do
      expect(described_class.new(nil, nav_area).update?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, nav_area).update?).to be false
    end

    it 'allows platform navigation managers' do
      expect(described_class.new(manager_user, nav_area).update?).to be true
    end
  end

  describe '#destroy?' do
    it 'denies guests' do
      expect(described_class.new(nil, nav_area).destroy?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, nav_area).destroy?).to be false
    end

    it 'allows managers to destroy unprotected areas' do
      expect(described_class.new(manager_user, nav_area).destroy?).to be true
    end

    it 'blocks destruction of protected areas even for managers' do
      expect(described_class.new(manager_user, protected_area).destroy?).to be false
    end
  end
end
