# frozen_string_literal: true

module BetterTogether
  # Background job that scans for pending federated sync tasks and dispatches pull jobs.
  # Connections that are already marked as running are skipped to prevent concurrent
  # duplicate syncs — the pull job itself enqueues the next page when a cursor is present.
  class FederatedSyncScanJob < ApplicationJob
    queue_as :platform_sync

    def perform(limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT)
      eligible_connections.find_each do |connection|
        ::BetterTogether::FederatedContentPullJob.perform_later(
          platform_connection_id: connection.id,
          cursor: connection.sync_cursor.presence,
          limit:
        )
      end
    end

    private

    def eligible_connections
      # Exclude connections already syncing in SQL to prevent duplicates;
      # policy methods are Ruby-only (multi-field JSONB logic) so filter in-process.
      ::BetterTogether::PlatformConnection.active
                                          .where("settings->>'last_sync_status' != ?", 'running')
                                          .select { |c| c.mirrored_content_enabled? && c.api_read_enabled? }
    end
  end
end
