# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformConnection do
  it 'has a valid factory' do
    connection = build(:better_together_platform_connection)

    expect(connection).to be_valid
  end

  describe 'validations' do
    it 'requires source and target platforms to differ' do
      platform = create(:better_together_platform)
      connection = build(:better_together_platform_connection, source_platform: platform, target_platform: platform)

      expect(connection).not_to be_valid
      expect(connection.errors[:target_platform_id]).to include('must differ from source platform')
    end

    it 'does not allow duplicate directed edges' do
      source_platform = create(:better_together_platform)
      target_platform = create(:better_together_platform)
      create(:better_together_platform_connection, source_platform:, target_platform:)

      duplicate = build(:better_together_platform_connection, source_platform:, target_platform:)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:source_platform_id]).to be_present
    end
  end

  describe '#peer_for' do
    it 'returns the opposite platform for the source platform' do
      connection = create(:better_together_platform_connection)

      expect(connection.peer_for(connection.source_platform)).to eq(connection.target_platform)
    end

    it 'returns the opposite platform for the target platform' do
      connection = create(:better_together_platform_connection)

      expect(connection.peer_for(connection.target_platform)).to eq(connection.source_platform)
    end
  end

  describe '.for_platform' do
    it 'returns incoming and outgoing connections for a platform' do
      platform = create(:better_together_platform)
      outgoing = create(:better_together_platform_connection, source_platform: platform)
      incoming = create(:better_together_platform_connection, target_platform: platform)
      create(:better_together_platform_connection)

      expect(described_class.for_platform(platform)).to contain_exactly(outgoing, incoming)
    end
  end
end
