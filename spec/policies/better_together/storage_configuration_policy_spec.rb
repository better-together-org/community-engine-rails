# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::StorageConfigurationPolicy, type: :policy do
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }
  let(:config) { create(:better_together_storage_configuration) }

  describe '#index?' do
    it 'denies guests' do
      expect(described_class.new(nil, config)).not_to be_index
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, config)).not_to be_index
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, config).index?).to be true
    end
  end

  describe '#show?' do
    it 'denies guests' do
      expect(described_class.new(nil, config)).not_to be_show
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, config)).not_to be_show
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, config).show?).to be true
    end
  end

  describe '#create?' do
    it 'denies guests' do
      expect(described_class.new(nil, config)).not_to be_create
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, config)).not_to be_create
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, config).create?).to be true
    end
  end

  describe '#update?' do
    it 'denies guests' do
      expect(described_class.new(nil, config)).not_to be_update
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, config)).not_to be_update
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, config).update?).to be true
    end
  end

  describe '#destroy?' do
    it 'denies guests' do
      expect(described_class.new(nil, config)).not_to be_destroy
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, config)).not_to be_destroy
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, config).destroy?).to be true
    end
  end

  describe '#activate?' do
    it 'allows platform managers' do
      expect(described_class.new(manager_user, config).activate?).to be true
    end

    it 'denies non-manager users' do
      expect(described_class.new(normal_user, config)).not_to be_activate
    end
  end
end
