# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::FederatedContentExportService do
  describe '#call' do
    let(:source_platform) { create(:better_together_platform, :public) }
    let(:target_platform) { create(:better_together_platform, :community_engine_peer) }
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
      origins = result.seeds.map { |seed| seed['better_together'][:seed][:origin] }

      expect(payloads.map { |payload| payload[:type] }).to include('post', 'page', 'event')
      expect(payloads.map { |payload| payload[:id] }).to include(post.id, page.id, event.id)
      expect(origins).to all(include(profile: 'platform_shared', lane: 'platform_shared'))
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

    it 'exports a record whose rich text body is pathologically wrapped with a truncation marker, ' \
       'instead of failing the whole page (2026-09 production incident regression guard)' do
      creator = create(:better_together_person, federate_content: true)
      healthy_post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public',
                                                   published_at: 2.days.ago, updated_at: 2.days.ago)
      wrapped_event = create(:event, :with_pathologically_wrapped_description, creator:, platform: source_platform,
                                                                               privacy: 'public', starts_at: 2.days.from_now,
                                                                               ends_at: 2.days.from_now + 1.hour, updated_at: 1.day.ago)

      result = nil
      expect { result = described_class.call(connection:, limit: 10) }.not_to raise_error

      payloads_by_id = result.seeds.index_by { |seed| seed['better_together'][:payload][:id] }
                                   .transform_values { |seed| seed['better_together'][:payload] }
      expect(payloads_by_id.keys).to include(healthy_post.id, wrapped_event.id)
      expect(payloads_by_id[wrapped_event.id][:attributes][:description])
        .to eq(BetterTogether::Seeds::SafeRichText::TRUNCATED_MARKER)
      expect(result.skipped_count).to eq(0)
    end

    it 'skips a record entirely (rather than raising) if building its seed fails for a reason other than ' \
       'a guarded rich text body' do
      creator = create(:better_together_person, federate_content: true)
      healthy_post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public',
                                                   published_at: 2.days.ago, updated_at: 2.days.ago)
      broken_post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public',
                                                  published_at: 1.day.ago, updated_at: 1.day.ago)
      allow(BetterTogether::Seeds::FederatedSeedAttributes).to receive(:post_attributes)
        .with(broken_post, sync_depth: anything).and_raise(RuntimeError, 'boom')
      allow(BetterTogether::Seeds::FederatedSeedAttributes).to receive(:post_attributes)
        .with(healthy_post, sync_depth: anything).and_call_original

      result = nil
      expect { result = described_class.call(connection:, limit: 10) }.not_to raise_error

      ids = result.seeds.map { |seed| seed['better_together'][:payload][:id] }
      expect(ids).to include(healthy_post.id)
      expect(ids).not_to include(broken_post.id)
      expect(result.skipped_count).to eq(1)
    end

    it 'excludes person-authored content when the creator has not opted into federation' do
      creator = create(:better_together_person, federate_content: false)
      create(:better_together_post, creator:, platform: source_platform, privacy: 'public', published_at: 1.day.ago)

      result = described_class.call(connection:, limit: 10)

      expect(result.seeds).to be_empty
    end

    describe 'per-item federation_visibility tri-state' do
      it 'includes platform_default content when the creator opted in (regression guard, unchanged behavior)' do
        creator = create(:better_together_person, federate_content: true)
        post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public',
                                             published_at: 1.day.ago, federation_visibility: 'platform_default')

        result = described_class.call(connection:, limit: 10)
        expect(result.seeds.map { |seed| seed['better_together'][:payload][:id] }).to include(post.id)
      end

      it 'excludes platform_default content when the creator opted out (regression guard, unchanged behavior)' do
        creator = create(:better_together_person, federate_content: false)
        post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public',
                                             published_at: 1.day.ago, federation_visibility: 'platform_default')

        result = described_class.call(connection:, limit: 10)
        expect(result.seeds.map { |seed| seed['better_together'][:payload][:id] }).not_to include(post.id)
      end

      it 'includes federate content even when the creator has not opted into federation' do
        creator = create(:better_together_person, federate_content: false)
        post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public',
                                             published_at: 1.day.ago, federation_visibility: 'federate')

        result = described_class.call(connection:, limit: 10)
        expect(result.seeds.map { |seed| seed['better_together'][:payload][:id] }).to include(post.id)
      end

      it 'excludes no_federate content even when the creator opted in and the connection allows the type' do
        creator = create(:better_together_person, federate_content: true)
        post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public',
                                             published_at: 1.day.ago, federation_visibility: 'no_federate')

        result = described_class.call(connection:, limit: 10)
        expect(result.seeds.map { |seed| seed['better_together'][:payload][:id] }).not_to include(post.id)
      end

      it 'excludes no_federate content with no creator (system-owned content)' do
        page = create(:better_together_page, creator: nil, platform: source_platform, privacy: 'public',
                                             published_at: 1.day.ago, federation_visibility: 'no_federate')

        result = described_class.call(connection:, limit: 10)
        expect(result.seeds.map { |seed| seed['better_together'][:payload][:id] }).not_to include(page.id)
      end

      it 'applies the same tri-state logic to events' do
        creator = create(:better_together_person, federate_content: false)
        event = create(:event, creator:, platform: source_platform, privacy: 'public',
                               starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour,
                               federation_visibility: 'federate')

        result = described_class.call(connection:, limit: 10)
        expect(result.seeds.map { |seed| seed['better_together'][:payload][:id] }).to include(event.id)
      end
    end

    describe 'per-connection FederationContentGrant' do
      it 'excludes federate content when this connection has an explicit denied grant' do
        creator = create(:better_together_person, federate_content: true)
        post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public',
                                             published_at: 1.day.ago, federation_visibility: 'federate')
        create(:better_together_federation_content_grant, federatable: post, platform_connection: connection,
                                                          status: 'denied')

        result = described_class.call(connection:, limit: 10)
        expect(result.seeds.map { |seed| seed['better_together'][:payload][:id] }).not_to include(post.id)
      end

      it 'includes platform_default content when this connection has an explicit allowed grant, ' \
         'even though the creator opted out globally' do
        creator = create(:better_together_person, federate_content: false)
        post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public',
                                             published_at: 1.day.ago, federation_visibility: 'platform_default')
        create(:better_together_federation_content_grant, federatable: post, platform_connection: connection,
                                                          status: 'allowed')

        result = described_class.call(connection:, limit: 10)
        expect(result.seeds.map { |seed| seed['better_together'][:payload][:id] }).to include(post.id)
      end

      it 'still excludes no_federate content even with an explicit allowed grant for this connection' do
        creator = create(:better_together_person, federate_content: true)
        post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public',
                                             published_at: 1.day.ago, federation_visibility: 'no_federate')
        create(:better_together_federation_content_grant, federatable: post, platform_connection: connection,
                                                          status: 'allowed')

        result = described_class.call(connection:, limit: 10)
        expect(result.seeds.map { |seed| seed['better_together'][:payload][:id] }).not_to include(post.id)
      end

      it 'ignores a grant scoped to a different connection' do
        other_connection = create(
          :better_together_platform_connection, :active,
          source_platform: create(:better_together_platform), target_platform: create(:better_together_platform),
          share_posts: true
        )
        creator = create(:better_together_person, federate_content: false)
        post = create(:better_together_post, creator:, platform: source_platform, privacy: 'public',
                                             published_at: 1.day.ago, federation_visibility: 'platform_default')
        create(:better_together_federation_content_grant, federatable: post, platform_connection: other_connection,
                                                          status: 'allowed')

        result = described_class.call(connection:, limit: 10)
        expect(result.seeds.map { |seed| seed['better_together'][:payload][:id] }).not_to include(post.id)
      end
    end
  end
end
