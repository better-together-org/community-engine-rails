# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Robot do
  it_behaves_like 'an author model'

  describe '.resolve' do
    let(:platform) { create(:platform) }
    let!(:global_robot) do
      create(:robot, :global, identifier: 'translation', name: 'Global Translation')
    end

    it 'prefers an active platform-specific robot over the global fallback' do
      platform_robot = create(:robot, platform:, identifier: 'translation', name: 'Platform Translation')

      resolved = described_class.resolve(identifier: 'translation', platform:)

      expect(resolved).to eq(platform_robot)
      expect(resolved).not_to eq(global_robot)
    end

    it 'falls back to the global active robot when no platform-specific robot exists' do
      resolved = described_class.resolve(identifier: 'translation', platform:)

      expect(resolved).to eq(global_robot)
    end

    it 'ignores inactive robot records' do
      create(:robot, platform:, identifier: 'translation', active: false)

      resolved = described_class.resolve(identifier: 'translation', platform:)

      expect(resolved).to eq(global_robot)
    end
  end

  describe '#settings_hash' do
    it 'returns indifferent access for parsed settings' do
      robot = build(:robot, settings: { assume_model_exists: true })

      expect(robot.settings_hash[:assume_model_exists]).to be(true)
      expect(robot.settings_hash['assume_model_exists']).to be(true)
    end
  end

  describe '.available_for_platform' do
    let(:platform) { create(:platform) }
    let!(:global_robot) { create(:robot, :global, name: 'Global Robot') }
    let!(:platform_robot) { create(:robot, platform:, name: 'Platform Robot') }

    it 'returns global and platform-specific active robots' do
      expect(described_class.available_for_platform(platform)).to include(global_robot, platform_robot)
    end
  end

  describe '#select_option_title' do
    it 'renders a robot-specific select label' do
      robot = build(:robot, identifier: 'writer', name: 'Writer Bot')

      expect(robot.select_option_title).to eq('Writer Bot - robot:writer')
    end
  end

  describe 'community action network identity helpers' do
    it 'exposes governed agent metadata for robots' do
      robot = build(:robot, identifier: 'release-bot', name: 'Release Bot')

      expect(robot.governed_agent?).to be(true)
      expect(robot.governed_agent_type).to eq('robot')
      expect(robot.governed_agent_identifier).to eq('release-bot')
      expect(robot.governed_agent_display_name).to eq('Release Bot')
      expect(robot.governed_agent_key).to eq('robot:release-bot')
      expect(robot.governed_agent_label).to eq('Release Bot (robot)')
    end

    it 'can satisfy agreement checks as a governed agent' do
      robot = create(:robot, identifier: 'release-bot', name: 'Release Bot')
      agreement = BetterTogether::Agreement.find_or_create_by!(identifier: 'content_publishing_agreement') do |record|
        record.title = 'Content Publishing Agreement'
        record.privacy = 'public'
        record.protected = true
      end
      create(:better_together_agreement_participant, agreement:, participant: robot, accepted_at: Time.current)

      expect(robot.accepted_agreement?('content_publishing_agreement')).to be(true)
    end
  end

  describe '#to_s' do
    it 'returns the robot name' do
      robot = build(:robot, name: 'Release Bot')

      expect(robot.to_s).to eq('Release Bot')
    end
  end

  describe '#select_option_title' do
    it 'includes the robot identifier and author type' do
      robot = build(:robot, identifier: 'release-bot', name: 'Release Bot')

      expect(robot.select_option_title).to eq('Release Bot - @release-bot (robot)')
    end
  end

  describe '.available_for_platform' do
    it 'includes platform-specific and global active robots for the given platform' do
      platform = create(:better_together_platform)
      platform_robot = create(:robot, platform:, identifier: 'platform-bot')
      global_robot = create(:robot, :global, identifier: 'global-bot')
      create(:robot, platform: create(:better_together_platform), identifier: 'other-bot')

      result = described_class.available_for_platform(platform)

      expect(result).to include(platform_robot, global_robot)
    end
  end
end
