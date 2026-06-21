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

  describe 'bot access token support' do
    let(:robot) do
      create(
        :robot,
        identifier: 'reader-bot',
        settings: {
          bot_access_enabled: true,
          bot_access_scopes: %w[read_public_content read_private_content],
          bot_access_token_digest: described_class.bot_access_token_digest('secret-token')
        }
      )
    end

    it 'treats private-content scope as including public-content reads' do
      expect(robot.allows_bot_scope?('read_public_content')).to be(true)
      expect(robot.allows_content_privacy?('private')).to be(true)
    end

    it 'authenticates a platform robot from an identifier.secret token' do
      authenticated = described_class.authenticate_access_token('reader-bot.secret-token', platform: robot.platform)

      expect(authenticated).to eq(robot)
    end

    it 'rejects invalid secrets' do
      authenticated = described_class.authenticate_access_token('reader-bot.wrong-token', platform: robot.platform)

      expect(authenticated).to be_nil
    end
  end

  describe '.available_for_platform' do
    let(:platform) { create(:platform) }
    let!(:global_robot) { create(:robot, :global, name: 'Global Robot') }
    let!(:platform_robot) { create(:robot, platform:, name: 'Platform Robot') }

    it 'returns global and platform-specific active robots' do
      expect(described_class.available_for_platform(platform)).to include(global_robot, platform_robot)
    end

    it 'excludes robots from other platforms' do
      create(:robot, platform: create(:platform), name: 'Other Platform Robot')

      expect(described_class.available_for_platform(platform)).not_to include(
        described_class.find_by(name: 'Other Platform Robot')
      )
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
end
