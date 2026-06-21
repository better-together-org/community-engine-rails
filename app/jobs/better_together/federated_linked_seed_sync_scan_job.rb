# frozen_string_literal: true

module BetterTogether
  # Hourly scan job that enqueues a pull job for each active PersonAccessGrant
  # eligible for linked-content sync, passing the per-grant cursor so each
  # pull resumes from where it left off rather than restarting from page 1.
  class FederatedLinkedSeedSyncScanJob < ApplicationJob
    SCAN_LOCK_KEY = 'bt:federation:linked_seed_scan_lock'
    GRANT_DISPATCH_LOCK_NAMESPACE = 'bt:federation:linked_seed_dispatch'
    LOCK_TTL = 10.minutes.to_i

    queue_as :platform_sync

    def perform
      with_scan_lock { eligible_grants.find_each { |grant| enqueue_grant_pull(grant) } }
    ensure
      release_scan_lock_if_owner
    end

    private

    def with_scan_lock
      return unless acquire_scan_lock

      yield
    end

    def eligible_grants
      ::BetterTogether::PersonAccessGrant.current_active
                                         .joins(person_link: :platform_connection)
                                         .includes(:grantee_person, person_link: :platform_connection)
                                         .where.not(grantee_person_id: nil)
                                         .merge(
                                           ::BetterTogether::PlatformConnection.active
                                                                                    .linked_content_read_capable
                                                                                    .not_syncing
                                         )
    end

    RELEASE_LOCK_SCRIPT = <<~LUA
      if redis.call("get", KEYS[1]) == ARGV[1] then
        return redis.call("del", KEYS[1])
      else
        return 0
      end
    LUA
    private_constant :RELEASE_LOCK_SCRIPT

    def acquire_scan_lock
      Sidekiq.redis { |redis| redis.set(SCAN_LOCK_KEY, job_id, nx: true, ex: LOCK_TTL) }
    end

    def release_scan_lock_if_owner
      return if job_id.blank?

      Sidekiq.redis { |redis| redis.call('EVAL', RELEASE_LOCK_SCRIPT, 1, SCAN_LOCK_KEY, job_id) }
    end

    def acquire_dispatch_lock(grant, dispatch_token)
      Sidekiq.redis do |redis|
        redis.set(dispatch_lock_key(grant.id), dispatch_token, nx: true, ex: LOCK_TTL)
      end
    end

    def enqueue_grant_pull(grant)
      dispatch_token = dispatch_token_for(grant)
      return unless acquire_dispatch_lock(grant, dispatch_token)

      ::BetterTogether::FederatedLinkedSeedPullJob.perform_later(
        platform_connection_id: grant.person_link.platform_connection_id,
        recipient_person_id: grant.grantee_person_id,
        person_access_grant_id: grant.id,
        sync_cursor: grant.sync_cursor,
        dispatch_lock_token: dispatch_token
      )
    rescue StandardError
      release_dispatch_lock_if_owner(grant.id, dispatch_token)
      raise
    end

    def release_dispatch_lock_if_owner(grant_id, dispatch_token)
      return if grant_id.blank? || dispatch_token.blank?

      Sidekiq.redis do |redis|
        redis.call('EVAL', RELEASE_LOCK_SCRIPT, 1, dispatch_lock_key(grant_id), dispatch_token)
      end
    end

    def dispatch_lock_key(grant_id)
      "#{GRANT_DISPATCH_LOCK_NAMESPACE}/#{grant_id}"
    end

    def dispatch_token_for(grant)
      "#{job_id}:#{grant.id}:#{grant.sync_cursor.presence || 'initial'}"
    end
  end
end
