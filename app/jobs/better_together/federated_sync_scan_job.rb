# frozen_string_literal: true

module BetterTogether
  # Background job that scans for pending federated sync tasks and dispatches pull jobs.
  # Connections that are already marked as running are skipped to prevent concurrent
  # duplicate syncs — the pull job itself enqueues the next page when a cursor is present.
  #
  # A Redis lock (TTL 10 minutes) prevents a second scan from starting while one
  # is still running, eliminating the race window between scan and pull-job startup.
  class FederatedSyncScanJob < ApplicationJob
    LOCK_KEY = 'bt:federation:scan_lock'
    LOCK_TTL = 10.minutes.to_i

    queue_as :platform_sync

    def perform(limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT)
      acquired = Sidekiq.redis { |r| r.set(LOCK_KEY, job_id, nx: true, ex: LOCK_TTL) }
      return unless acquired

      begin
        eligible_connections.each do |connection|
          ::BetterTogether::FederatedContentPullJob.perform_later(
            platform_connection_id: connection.id,
            cursor: connection.sync_cursor.presence,
            limit:
          )
        end
      ensure
        Sidekiq.redis { |r| r.del(LOCK_KEY) }
      end
    end

    private

    def eligible_connections
      ::BetterTogether::PlatformConnection.active
                                          .content_read_capable
                                          .not_syncing
                                          .where("settings->>'content_sharing_policy' IN (?)",
                                                 %w[mirror_network_feed mirrored_publish_back])
    end
  end
end
