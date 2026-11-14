# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederationHub::ConnectionHealthSummaryService do
  describe '.call' do
    it 'returns a default (all-zero) summary when platform is nil' do
      expect(described_class.call(platform: nil)).to eq(
        total_count: 0, pending_count: 0, active_count: 0, healthy_count: 0, failed_count: 0
      )
    end

    it 'counts connections where the platform is either the source or the target' do
      platform = create(:better_together_platform)
      other_platform = create(:better_together_platform)
      create(:better_together_platform_connection, :active, source_platform: platform, target_platform: other_platform)
      create(:better_together_platform_connection, source_platform: other_platform, target_platform: platform)
      create(:better_together_platform_connection) # unrelated connection, not counted

      summary = described_class.call(platform:)

      expect(summary[:total_count]).to eq(2)
      expect(summary[:pending_count]).to eq(1)
      expect(summary[:active_count]).to eq(1)
    end

    it 'counts connections whose last sync failed' do
      platform = create(:better_together_platform)
      failed_connection = create(:better_together_platform_connection, :active, source_platform: platform)
      failed_connection.mark_sync_failed!(message: 'boom')
      create(:better_together_platform_connection, :active, source_platform: platform)

      summary = described_class.call(platform:)

      expect(summary[:failed_count]).to eq(1)
      expect(summary[:healthy_count]).to eq(1)
    end
  end
end
