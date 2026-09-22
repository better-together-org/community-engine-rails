# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::StorageConfigurationPolicy, type: :policy do
  def steward_of(platform)
    user = create(:better_together_user, :confirmed)
    BetterTogether::PersonPlatformMembership.create!(
      joinable: platform, member: user.person,
      role: BetterTogether::Role.find_by(identifier: 'platform_steward'), status: 'active'
    )
    user
  end

  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }
  # Explicit host platform — the factory otherwise builds its own unrelated
  # platform, which manager_user's (host-scoped) platform_manager role would
  # correctly no longer manage under per-platform scoping.
  let(:config) do
    create(:better_together_storage_configuration, platform: BetterTogether::Platform.find_by(host: true))
  end

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

  describe 'cross-tenant isolation' do
    let(:platform_a) { create(:better_together_platform) }
    let(:platform_b) { create(:better_together_platform) }
    let(:platform_b_config) { create(:better_together_storage_configuration, platform: platform_b) }

    it "denies a steward of platform A from managing platform B's storage configuration" do
      steward_a = steward_of(platform_a)

      expect(described_class.new(steward_a, platform_b_config).index?).to be false
      expect(described_class.new(steward_a, platform_b_config).show?).to be false
      expect(described_class.new(steward_a, platform_b_config).activate?).to be false
    end

    it "allows a steward of platform B to manage platform B's own storage configuration" do
      steward_b = steward_of(platform_b)

      expect(described_class.new(steward_b, platform_b_config).index?).to be true
      expect(described_class.new(steward_b, platform_b_config).show?).to be true
      expect(described_class.new(steward_b, platform_b_config).activate?).to be true
    end
  end
end
