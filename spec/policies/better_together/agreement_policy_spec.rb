# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AgreementPolicy, type: :policy do
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }
  let(:agreement) { create(:better_together_agreement) }

  describe '#show?' do
    it 'allows guests to view agreements' do
      expect(described_class.new(nil, agreement).show?).to be true
    end

    it 'allows authenticated users to view agreements' do
      expect(described_class.new(normal_user, agreement).show?).to be true
    end
  end

  describe '#accept?' do
    it 'allows guests to accept (public access matches show?)' do
      expect(described_class.new(nil, agreement).accept?).to be true
    end
  end

  describe '#index?' do
    it 'denies guests' do
      expect(described_class.new(nil, agreement).index?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, agreement).index?).to be false
    end

    it 'allows agreement managers' do
      expect(described_class.new(manager_user, agreement).index?).to be true
    end
  end

  describe '#create?' do
    it 'denies guests' do
      expect(described_class.new(nil, agreement).create?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, agreement).create?).to be false
    end

    it 'allows agreement managers' do
      expect(described_class.new(manager_user, agreement).create?).to be true
    end
  end

  describe '#update?' do
    it 'denies guests' do
      expect(described_class.new(nil, agreement).update?).to be false
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, agreement).update?).to be false
    end

    it 'allows agreement managers' do
      expect(described_class.new(manager_user, agreement).update?).to be true
    end
  end
end
