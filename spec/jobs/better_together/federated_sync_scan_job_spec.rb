# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederatedSyncScanJob do
  include ActiveJob::TestHelper
  describe 'queueing' do
    it 'uses the platform_sync queue' do
      expect(described_class.new.queue_name).to eq('platform_sync')
    end
  end

  describe '#perform' do
    let!(:eligible_connection) do
      create(
        :better_together_platform_connection,
        :active,
        content_sharing_policy: 'mirror_network_feed',
        federation_auth_policy: 'api_read',
        share_posts: true,
        allow_identity_scope: true,
        allow_content_read_scope: true
      )
    end
    let!(:ineligible_connection) do
      create(
        :better_together_platform_connection,
        :active,
        content_sharing_policy: 'none',
        federation_auth_policy: 'none'
      )
    end

    it 'enqueues pull jobs only for sync-eligible active connections' do
      expect do
        described_class.perform_now(limit: 25)
      end.to have_enqueued_job(BetterTogether::FederatedContentPullJob)
        .with(platform_connection_id: eligible_connection.id, cursor: nil, limit: 25)
        .on_queue('platform_sync')

      expect(enqueued_jobs.map { |job| job[:job] }).not_to include(ineligible_connection.class)
    end
  end
end
