# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe Content::FederatedPageMirrorService do
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

      it 'uses source_id when the target platform is local hosted' do
        remote_id = SecureRandom.uuid

        page = described_class.new(
          connection:,
          remote_attributes:,
          remote_id:,
          preserve_remote_uuid: true
        ).call

        expect(page.id).not_to eq(remote_id)
        expect(page.platform).to eq(target_platform)
        expect(page.source_id).to eq(remote_id)
        expect(page.last_synced_at).to be_present
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
          share_pages: true
        )

        page = described_class.new(
          connection: external_connection,
          remote_attributes:,
          remote_id:,
          preserve_remote_uuid: true
        ).call

        expect(page.id).to eq(remote_id)
        expect(page.source_id).to be_nil
        expect(page.platform).to eq(external_target)
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
        expect(page.platform).to eq(target_platform)
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
end
