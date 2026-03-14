# frozen_string_literal: true

module BetterTogether
  # Background job that scans for pending federated sync tasks and dispatches pull jobs.
  # Connections that are already marked as running are skipped to prevent concurrent
  # duplicate syncs — the pull job itself enqueues the next page when a cursor is present.
  class FederatedSyncScanJob < ApplicationJob
    queue_as :platform_sync

    def perform(limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT)
      eligible_connections.each do |connection|
        ::BetterTogether::FederatedContentPullJob.perform_later(
          platform_connection_id: connection.id,
          cursor: connection.sync_cursor.presence,
          limit:
        )
      end
    end

    private

    def eligible_connections
      ::BetterTogether::PlatformConnection.active
                                          .where("settings->>'last_sync_status' != ?", 'running')
                                          .where("settings->>'content_sharing_policy' IN (?)",
                                                 %w[mirror_network_feed mirrored_publish_back])
                                          .where("settings->>'federation_auth_policy' IN (?)",
                                                 %w[api_read api_write])
                                          .where("(settings->>'allow_content_read_scope')::boolean = true")
    end
  end
end
