# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::FederatedContentExportService do
  describe '#call' do
    let(:source_platform) { create(:better_together_platform, :community_engine_peer) }
    let(:target_platform) { create(:better_together_platform) }
    let(:connection) do
      create(
        :better_together_platform_connection,
        :active,
        source_platform:,
        target_platform:,
        content_sharing_policy: 'mirror_network_feed',
        share_posts: true,
        share_pages: true,
        share_events: true
      )
    end

    it 'exports local-origin public content for allowed content types' do
      creator = create(:better_together_person, federate_content: true)
      post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public', published_at: 1.day.ago)
      page = create(:better_together_page, creator:, platform: source_platform, privacy: 'public', published_at: 1.day.ago)
      event = create(:event, creator:, platform: source_platform, privacy: 'public', starts_at: 2.days.from_now,
                             ends_at: 2.days.from_now + 1.hour)

      result = described_class.call(connection:, limit: 10)
      payloads = result.seeds.map { |seed| seed['better_together'][:payload] }

      expect(payloads.map { |payload| payload[:type] }).to include('post', 'page', 'event')
      expect(payloads.map { |payload| payload[:id] }).to include(post.id, page.id, event.id)
      expect(result.next_cursor).to be_present
    end

    it 'excludes mirrored remote-origin content from export' do
      create(
        :better_together_post,
        platform: source_platform,
        privacy: 'public',
        published_at: 1.day.ago,
        source_id: 'remote-post-1'
      )

      result = described_class.call(connection:, limit: 10)

      expect(result.seeds).to be_empty
    end

    it 'respects the cursor and limit' do
      creator = create(:better_together_person, federate_content: true)
      first_post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public', published_at: 2.days.ago,
                                                 updated_at: 2.days.ago)
      second_post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public', published_at: 1.day.ago,
                                                  updated_at: 1.day.ago)

      first_result = described_class.call(connection:, limit: 1)
      second_result = described_class.call(connection:, cursor: first_result.next_cursor, limit: 10)

      expect(first_result.seeds.length).to eq(1)
      expect(first_result.seeds.first['better_together'][:payload][:id]).to eq(first_post.id)
      expect(second_result.seeds.map { |seed| seed['better_together'][:payload][:id] }).to include(second_post.id)
    end

    it 'excludes person-authored content when the creator has not opted into federation' do
      creator = create(:better_together_person, federate_content: false)
      create(:better_together_post, creator:, platform: source_platform, privacy: 'public', published_at: 1.day.ago)

      result = described_class.call(connection:, limit: 10)

      expect(result.seeds).to be_empty
    end
  end
end
