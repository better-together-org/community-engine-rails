# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::RobotPolicy, type: :policy do
  # platform_manager gains manage_platform on the host platform.
  # The robot must be created on that same host platform so the manager can manage it.
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }
  let(:host_platform) { BetterTogether::Platform.find_by!(host: true) }
  let(:platform_robot) { create(:better_together_robot, platform: host_platform) }
  let(:global_robot) { create(:better_together_robot, :global) }

  before { manager_user } # ensure host platform exists before building robots

  describe '#index?' do
    it 'denies guests (no manageable platforms)' do
      expect(described_class.new(nil, BetterTogether::Robot).index?).to be false
    end

    it 'denies users who manage no platforms' do
      expect(described_class.new(normal_user, BetterTogether::Robot).index?).to be false
    end

    it 'allows users who manage at least one platform' do
      expect(described_class.new(manager_user, BetterTogether::Robot).index?).to be true
    end
  end

  describe '#show?' do
    context 'with a platform-scoped robot' do
      it 'allows the platform manager to view it' do
        expect(described_class.new(manager_user, platform_robot).show?).to be true
      end

      it 'denies a user who does not manage that platform' do
        expect(described_class.new(normal_user, platform_robot).show?).to be false
      end
    end

    context 'with a global robot (no platform)' do
      it 'allows viewing by a platform manager' do
        expect(described_class.new(manager_user, global_robot).show?).to be true
      end
    end
  end

  describe '#create?' do
    it 'allows platform managers to create a robot on their platform' do
      expect(described_class.new(manager_user, platform_robot).create?).to be true
    end

    it 'denies non-managers' do
      expect(described_class.new(normal_user, platform_robot).create?).to be false
    end

    it 'denies guests' do
      expect(described_class.new(nil, platform_robot).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows platform managers to update their platform robot' do
      expect(described_class.new(manager_user, platform_robot).update?).to be true
    end

    it 'denies non-managers' do
      expect(described_class.new(normal_user, platform_robot).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows platform managers to destroy their platform robot' do
      expect(described_class.new(manager_user, platform_robot).destroy?).to be true
    end

    it 'denies non-managers' do
      expect(described_class.new(normal_user, platform_robot).destroy?).to be false
    end
  end
end
