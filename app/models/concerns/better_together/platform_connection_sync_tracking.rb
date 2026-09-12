# frozen_string_literal: true

module BetterTogether
  # Mixin for sync state tracking on PlatformConnection.
  module PlatformConnectionSyncTracking
    extend ActiveSupport::Concern

    # Backoff on consecutive sync failures so a permanently broken connection isn't
    # re-dispatched on every scan tick forever: 5 min, doubling, capped at 6 hr.
    SYNC_BACKOFF_BASE_SECONDS = 300
    SYNC_BACKOFF_MAX_SECONDS = 21_600

    # Circuit breaker: a connection this deep into a failure streak has already
    # spent hours at the max backoff without recovering (streak 8 = backoff
    # already capped at 6h) -- the 2026-09 NLO<->CE runaway reached streaks of
    # 54-129 with no automatic stop. Past this threshold, suspend rather than
    # keep scheduling retries; a human has to look at it and re-activate.
    SYNC_FAILURE_SUSPEND_THRESHOLD = 20

    def sync_idle?
      last_sync_status == 'idle'
    end

    def sync_running?
      last_sync_status == 'running'
    end

    def sync_succeeded?
      last_sync_status == 'succeeded'
    end

    def sync_failed?
      last_sync_status == 'failed'
    end

    def sync_healthy?
      !sync_failed?
    end

    # Mirrors the backoff clause of the `due_for_sync` scope, for a single
    # in-memory instance rather than a query - used by FederatedContentPullJob
    # to recheck backoff before self-enqueuing the next page.
    def sync_backoff_active?
      until_time = parse_time_value(sync_backoff_until)
      until_time.present? && until_time > Time.current
    end

    def last_sync_started_at_time
      parse_time_value(last_sync_started_at)
    end

    def last_synced_at_time
      parse_time_value(last_synced_at)
    end

    def last_sync_error_at_time
      parse_time_value(last_sync_error_at)
    end

    def mark_sync_started!(cursor: nil, started_at: Time.current)
      persist_settings!(
        sync_cursor: normalized_cursor(cursor),
        last_sync_status: 'running',
        last_sync_started_at: started_at.iso8601,
        last_sync_error_at: '',
        last_sync_error_message: ''
      )
      record_sync_activity('platform_connection.sync_started')
    end

    # `final:` distinguishes a fully-completed pull (no more pages) from an
    # intermediate page. Only a completed pull clears the failure streak and
    # backoff — otherwise a connection that can serve exactly one page before
    # failing would reset its backoff on every scan and be retried forever.
    def mark_sync_succeeded!(cursor: nil, item_count: 0, synced_at: Time.current, message: nil, final: true)
      attrs = {
        sync_cursor: normalized_cursor(cursor),
        last_sync_status: 'succeeded',
        last_synced_at: synced_at.iso8601,
        last_sync_error_at: '',
        last_sync_error_message: message.to_s.truncate(500),
        last_sync_item_count: item_count.to_i
      }
      attrs.merge!(sync_failure_streak: 0, sync_backoff_until: '') if final
      persist_settings!(attrs)
      record_sync_activity('platform_connection.sync_succeeded', parameters: { item_count: item_count.to_i })
    end

    # `retry_after` (seconds) is the remote's own requested cool-off from a
    # rate-limit response; the effective backoff is the longer of that and our
    # exponential schedule.
    #
    # Returns true if this failure tripped the circuit breaker (connection
    # suspended) so callers (FederatedContentPullJob) can stop re-raising and
    # let Sidekiq's own retry schedule fall away instead of compounding the
    # backoff we already computed here.
    def mark_sync_failed!(message:, cursor: nil, failed_at: Time.current, retry_after: nil)
      streak = sync_failure_streak.to_i + 1
      persist_settings!(
        sync_cursor: normalized_cursor(cursor),
        last_sync_status: 'failed',
        last_sync_error_at: failed_at.iso8601,
        last_sync_error_message: message.to_s.truncate(500),
        sync_failure_streak: streak,
        sync_backoff_until: (failed_at + sync_backoff_interval(streak, retry_after)).iso8601
      )
      record_sync_activity('platform_connection.sync_failed', parameters: { message: message.to_s.truncate(500) })

      trip_circuit_breaker!(streak)
    end

    private

    # Storext attributes (sync_cursor, last_sync_status, sync_failure_streak,
    # etc.) all live in the single `settings` JSONB column. `update!` on them
    # is a full validated save -- including an optimistic-locking `lock_version`
    # bump -- on every single sync page; one production connection reached a
    # lock_version of 7.27M over ~5 months of the runaway. These fields are
    # internal bookkeeping updated many times a minute during an active sync,
    # not user-facing model state, so `update_columns` (no validations, no
    # callbacks, no lock_version bump) on the raw `settings` column is the
    # correct persistence for them. Contrast with `trip_circuit_breaker!`
    # below, which deliberately uses a real `update!` for the `status` enum
    # column so the existing `notify_reviewers_of_status_change` callback
    # still fires -- that transition is rare and should go through full
    # ActiveRecord machinery.
    def persist_settings!(changes)
      merged = settings.dup
      changes.each { |key, value| merged[key.to_s] = value }
      update_columns(settings: merged)
    end

    # Named with `!`, not `?`: this may mutate/suspend the connection as a
    # side effect, not just query state -- a bare predicate name would hide
    # that from callers.
    def trip_circuit_breaker!(streak) # rubocop:disable Naming/PredicateMethod
      return false if streak < SYNC_FAILURE_SUSPEND_THRESHOLD
      return false unless respond_to?(:active?) && active?

      update!(status: self.class::STATUS_VALUES[:suspended])
      record_sync_activity(
        'platform_connection.sync_circuit_breaker_tripped',
        parameters: { sync_failure_streak: streak, suspend_threshold: SYNC_FAILURE_SUSPEND_THRESHOLD }
      )
      true
    end

    def sync_backoff_interval(streak, retry_after = nil)
      exponential = [SYNC_BACKOFF_BASE_SECONDS * (2**(streak - 1)), SYNC_BACKOFF_MAX_SECONDS].min
      [exponential, retry_after.to_i].max.seconds
    end

    # PlatformConnection deliberately does not include TrackedActivity/PublicActivity::Model
    # (it has no privacy column, and connection audit activity must never leak into the
    # public ActivityPolicy::Scope-filtered feed) — so activities are recorded directly
    # rather than through the trackable.create_activity convenience method. Consumers
    # (FederationHub::ActivityFeedService) query BetterTogether::Activity for these records
    # directly, gating visibility via controller-level permission checks instead.
    def record_sync_activity(key, parameters: {})
      ::BetterTogether::Activity.create!(trackable: self, key:, parameters:)
    end

    def normalized_cursor(value)
      value.to_s
    end

    def parse_time_value(value)
      return if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end
  end
end
