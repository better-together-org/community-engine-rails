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
        described_class.perform_now(pull_limit: 25)
      end.to have_enqueued_job(BetterTogether::FederatedContentPullJob)
        .with(platform_connection_id: eligible_connection.id, cursor: nil, limit: 25)
        .on_queue('platform_sync')

      pull_jobs = enqueued_jobs.select { |job| job[:job] == BetterTogether::FederatedContentPullJob }
      enqueued_connection_ids = pull_jobs.map { |job| job[:args].first&.dig('platform_connection_id') }
      # Positive: exactly one job, for the eligible connection
      expect(enqueued_connection_ids).to contain_exactly(eligible_connection.id)
      # Negative: ineligible connection must not have been enqueued
      expect(enqueued_connection_ids).not_to include(ineligible_connection.id)
    end

    it 'does not enqueue pull jobs for inaccessible remote connections' do
      remote_source_platform = create(:better_together_platform, :community_engine_peer, external: true)
      remote_connection = create(
        :better_together_platform_connection,
        :active,
        source_platform: remote_source_platform,
        target_platform: create(:better_together_platform),
        content_sharing_policy: 'mirror_network_feed',
        federation_auth_policy: 'api_read',
        share_posts: true,
        allow_identity_scope: true,
        allow_content_read_scope: true
      )

      allow(BetterTogether::Federation::Transport::HttpAdapter)
        .to receive(:accessible?)
        .with(connection: remote_connection)
        .and_return(false)

      described_class.perform_now(pull_limit: 25)

      pull_jobs = enqueued_jobs.select { |job| job[:job] == BetterTogether::FederatedContentPullJob }
      enqueued_connection_ids = pull_jobs.map { |job| job[:args].first&.dig('platform_connection_id') }

      expect(enqueued_connection_ids).not_to include(remote_connection.id)
      expect(remote_connection.reload.last_sync_status).to eq('failed')
      expect(remote_connection.last_sync_error_message).to include('source platform is not reachable')
    end
  end
end
