# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::FederatedSeedBuilder do
  it 'builds a deterministic platform-shared seed envelope for a post' do
    source_platform = create(:better_together_platform, :community_engine_peer)
    target_platform = create(:better_together_platform)
    connection = create(:better_together_platform_connection, :active, source_platform:, target_platform:)
    post = create(:better_together_post, platform: source_platform, privacy: 'public', published_at: 1.day.ago)

    seed = described_class.call(record: post, connection:, lane: 'platform_shared')

    expect(seed['better_together'][:seed][:origin][:lane]).to eq('platform_shared')
    expect(seed['better_together'][:seed][:origin][:profile]).to eq('platform_shared')
    expect(seed['better_together'][:payload][:type]).to eq('post')
    expect(seed['better_together'][:payload][:id]).to eq(post.id)
  end
end
