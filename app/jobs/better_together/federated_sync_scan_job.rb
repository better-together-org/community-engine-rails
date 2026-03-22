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

    def perform(connection_limit: nil, pull_limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT)
      acquired = Sidekiq.redis { |r| r.set(LOCK_KEY, job_id, nx: true, ex: LOCK_TTL) }
      return unless acquired

      begin
        connections = connection_limit ? eligible_connections.limit(connection_limit) : eligible_connections
        connections.find_each do |connection|
          ::BetterTogether::FederatedContentPullJob.perform_later(
            platform_connection_id: connection.id,
            cursor: connection.sync_cursor.presence,
            limit: pull_limit
          )
        end
      ensure
        # Only release the lock if we still own it — avoids releasing a lock acquired
        # by a later job when our own lock naturally expired during a long run.
        release_lock_if_owner
      end
    end

    private

    def eligible_connections
      ::BetterTogether::PlatformConnection.active
                                          .content_read_capable
                                          .not_syncing
                                          # rubocop:disable BetterTogether/NoRawSqlInQueries -- PostgreSQL JSONB ->> operator has no Arel equivalent
                                          .where(Arel.sql("settings->>'content_sharing_policy' IN ('mirror_network_feed', 'mirrored_publish_back')"))
                                          # rubocop:enable BetterTogether/NoRawSqlInQueries
    end

    # Atomically release the Redis lock only if this job still owns it.
    # Uses a Lua script so the check-and-delete is a single atomic operation,
    # preventing a TOCTOU race between reading the owner and deleting the key.
    RELEASE_LOCK_SCRIPT = <<~LUA
      if redis.call("get", KEYS[1]) == ARGV[1] then
        return redis.call("del", KEYS[1])
      else
        return 0
      end
    LUA
    private_constant :RELEASE_LOCK_SCRIPT

    def release_lock_if_owner
      Sidekiq.redis { |r| r.call('EVAL', RELEASE_LOCK_SCRIPT, 1, LOCK_KEY, job_id) }
    end
  end
end
