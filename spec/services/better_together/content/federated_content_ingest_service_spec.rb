# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe Content::FederatedContentIngestService do
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
      let(:seeds) do
        [
          {
            'better_together' => {
              version: '1.0',
              seed: {
                type: 'BetterTogether::Seed',
                identifier: "seed-post-#{SecureRandom.hex(4)}",
                created_by: 'FederatedExport',
                created_at: Time.current.utc.iso8601,
                description: 'Remote post seed',
                origin: { lane: 'platform_shared', content_type: 'post' }
              },
              payload: {
                type: 'post',
                id: SecureRandom.uuid,
                preserve_remote_uuid: true,
                attributes: {
                  title: 'Remote Post',
                  content: 'Post content',
                  identifier: 'remote-post',
                  privacy: 'public'
                }
              }
            }
          },
          {
            'better_together' => {
              version: '1.0',
              seed: {
                type: 'BetterTogether::Seed',
                identifier: "seed-page-#{SecureRandom.hex(4)}",
                created_by: 'FederatedExport',
                created_at: Time.current.utc.iso8601,
                description: 'Remote page seed',
                origin: { lane: 'platform_shared', content_type: 'page' }
              },
              payload: {
                type: 'page',
                id: 'legacy-page-42',
                attributes: {
                  title: 'Remote Page',
                  content: 'Page content',
                  identifier: 'remote-page',
                  privacy: 'public'
                }
              }
            }
          },
          {
            'better_together' => {
              version: '1.0',
              seed: {
                type: 'BetterTogether::Seed',
                identifier: "seed-event-#{SecureRandom.hex(4)}",
                created_by: 'FederatedExport',
                created_at: Time.current.utc.iso8601,
                description: 'Remote event seed',
                origin: { lane: 'platform_shared', content_type: 'event' }
              },
              payload: {
                type: 'event',
                id: 'legacy-event-42',
                attributes: {
                  name: 'Remote Event',
                  description: 'Event content',
                  identifier: 'remote-event',
                  privacy: 'public',
                  starts_at: 2.days.from_now,
                  ends_at: 2.days.from_now + 1.hour,
                  duration_minutes: 60,
                  timezone: 'UTC'
                }
              }
            }
          },
          {
            'better_together' => {
              version: '1.0',
              seed: {
                type: 'BetterTogether::Seed',
                identifier: "seed-unknown-#{SecureRandom.hex(4)}",
                created_by: 'FederatedExport',
                created_at: Time.current.utc.iso8601,
                description: 'Unknown seed',
                origin: { lane: 'platform_shared', content_type: 'unknown' }
              },
              payload: {
                type: 'unknown',
                id: 'unsupported-1',
                attributes: {}
              }
            }
          }
        ]
      end

      it 'dispatches supported content types to their importer services' do
        result = described_class.call(connection:, seeds:)

        expect(result.processed_count).to eq(3)
        expect(result.imported_seeds.length).to eq(3)
        expect(result.imported_records.map(&:class)).to contain_exactly(
          BetterTogether::Post,
          BetterTogether::Page,
          BetterTogether::Event
        )
        expect(result.unsupported_seeds.length).to eq(1)
        expect(result.planting).to be_completed
      end

      it 'imports records relative to the target platform current context' do
        previous_platform = Current.platform

        described_class.call(connection:, seeds:)

        post = BetterTogether::Post.find_by(identifier: 'remote-post')
        page = BetterTogether::Page.find_by(identifier: 'remote-page')
        event = BetterTogether::Event.find_by(identifier: 'remote-event')

        expect(Current.platform).to eq(previous_platform)
        expect(post.platform).to eq(target_platform)
        expect(post.source_id).to be_present
        expect(page.platform).to eq(target_platform)
        expect(page.source_id).to eq('legacy-page-42')
        expect(event.platform).to eq(target_platform)
        expect(event.source_id).to eq('legacy-event-42')
      end

      it 'requires a connection' do
        expect do
          described_class.call(connection: nil, seeds:)
        end.to raise_error(ArgumentError, /connection is required/)
      end
    end
  end
end
