# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Robot do
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
end
