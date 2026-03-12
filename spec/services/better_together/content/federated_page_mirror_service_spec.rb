# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::FederatedPageMirrorService do
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
        share_pages: true
      )
    end
    let(:remote_attributes) do
      {
        title: 'Remote Page',
        content: 'Remote page content',
        identifier: 'remote-page',
        privacy: 'public',
        published_at: 1.day.ago,
        meta_description: 'Remote page description',
        keywords: 'remote,page'
      }
    end

    it 'preserves the remote UUID for CE-compatible sources' do
      remote_id = SecureRandom.uuid

      page = described_class.new(
        connection:,
        remote_attributes:,
        remote_id:,
        preserve_remote_uuid: true
      ).call

      expect(page.id).to eq(remote_id)
      expect(page.platform).to eq(source_platform)
      expect(page.source_id).to be_nil
      expect(page.last_synced_at).to be_present
    end

    it 'falls back to source_id for non-UUID remote identifiers' do
      page = described_class.new(
        connection:,
        remote_attributes:,
        remote_id: 'legacy-page-42',
        preserve_remote_uuid: false
      ).call

      expect(page.id).not_to eq('legacy-page-42')
      expect(page.source_id).to eq('legacy-page-42')
      expect(page.platform).to eq(source_platform)
    end

    it 'updates an existing mirrored page on repeat import' do
      existing = described_class.new(
        connection:,
        remote_attributes:,
        remote_id: 'legacy-page-42'
      ).call

      updated = described_class.new(
        connection:,
        remote_attributes: remote_attributes.merge(title: 'Updated Remote Page'),
        remote_id: 'legacy-page-42'
      ).call

      expect(updated.id).to eq(existing.id)
      expect(updated.title).to eq('Updated Remote Page')
    end

    it 'rejects mirroring when the connection policy does not allow pages' do
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
