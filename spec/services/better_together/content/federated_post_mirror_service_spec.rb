# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::FederatedPostMirrorService do
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
        share_posts: true
      )
    end
    let(:remote_attributes) do
      {
        title: 'Remote Post',
        content: 'Remote content',
        identifier: 'remote-post',
        privacy: 'public',
        published_at: 1.day.ago
      }
    end

    it 'uses source_id when the target platform is local hosted' do
      remote_id = SecureRandom.uuid

      post = described_class.new(
        connection:,
        remote_attributes:,
        remote_id:,
        preserve_remote_uuid: true
      ).call

      expect(post.id).not_to eq(remote_id)
      expect(post.platform).to eq(target_platform)
      expect(post.source_id).to eq(remote_id)
      expect(post.last_synced_at).to be_present
    end

    it 'preserves the remote UUID when the target platform is external' do
      remote_id = SecureRandom.uuid
      external_target = create(:better_together_platform, :community_engine_peer)
      external_connection = create(
        :better_together_platform_connection,
        :active,
        source_platform:,
        target_platform: external_target,
        content_sharing_policy: 'mirror_network_feed',
        share_posts: true
      )

      post = described_class.new(
        connection: external_connection,
        remote_attributes:,
        remote_id:,
        preserve_remote_uuid: true
      ).call

      expect(post.id).to eq(remote_id)
      expect(post.source_id).to be_nil
      expect(post.platform).to eq(external_target)
    end

    it 'falls back to source_id for non-UUID remote identifiers' do
      post = described_class.new(
        connection:,
        remote_attributes:,
        remote_id: 'legacy-post-42',
        preserve_remote_uuid: false
      ).call

      expect(post.id).not_to eq('legacy-post-42')
      expect(post.source_id).to eq('legacy-post-42')
      expect(post.platform).to eq(target_platform)
    end

    it 'updates an existing mirrored post on repeat import' do
      existing = described_class.new(
        connection:,
        remote_attributes:,
        remote_id: 'legacy-post-42'
      ).call

      updated = described_class.new(
        connection:,
        remote_attributes: remote_attributes.merge(title: 'Updated Remote Post'),
        remote_id: 'legacy-post-42'
      ).call

      expect(updated.id).to eq(existing.id)
      expect(updated.title).to eq('Updated Remote Post')
    end

    it 'rejects mirroring when the connection policy does not allow posts' do
      connection.update!(content_sharing_policy: 'none')

      expect do
        described_class.new(
          connection:,
          remote_attributes:,
          remote_id: SecureRandom.uuid,
          preserve_remote_uuid: true
        ).call
      end.to raise_error(ArgumentError, /not authorized/)
    end
  end
end
