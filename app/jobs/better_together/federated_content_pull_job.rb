# frozen_string_literal: true

module BetterTogether
  # Pulls a paginated batch of federated content from a remote platform,
  # ingests it inline, then enqueues the next page if a cursor is returned.
  # Seeds are never serialised into job arguments to avoid large Redis payloads.
  class FederatedContentPullJob < ApplicationJob # rubocop:disable Metrics/ClassLength
    # Small randomised gap before fetching the next page so a large feed isn't
    # paginated as one tight burst against the remote's per-IP rate limit.
    NEXT_PAGE_DELAY = (2..6)

    # Defense in depth against any future cursor bug reproducing the 2026-09
    # NLO<->CE runaway (a stuck cursor self-enqueued indefinitely, no page
    # cap existed to stop it). A single connection sync legitimately paginating
    # this deep is already unusual; past this, stop and let the next scheduled
    # scan pick it back up rather than keep tight-looping in this job chain.
    MAX_PAGES_PER_DISPATCH = 500

    queue_as :platform_sync
    discard_on ActiveRecord::StaleObjectError
    # A rate-limited remote is handled by marking the connection failed with a
    # cool-off (honouring Retry-After); the hourly sync scan re-dispatches once
    # sync_backoff_until passes. Retrying the job here would just re-hit the
    # throttle, so drop it rather than run Sidekiq's default retry schedule.
    discard_on ::BetterTogether::Federation::Transport::HttpAdapter::RateLimitedError

    def perform( # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists
      platform_connection_id:, cursor: nil, limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT, page: 1
    )
      connection = ::BetterTogether::PlatformConnection.find(platform_connection_id)
      connection.mark_sync_started!(cursor:)

      result = ::BetterTogether::FederatedContentPullService.call(connection:, cursor:, limit:)
      final = result.next_cursor.blank?

      if result.seeds.blank?
        connection.mark_sync_succeeded!(cursor: result.next_cursor, final:)
      else
        ingest_result = ::BetterTogether::Content::FederatedContentIngestService.call(connection:, seeds: result.seeds)
        connection.mark_sync_succeeded!(
          cursor: result.next_cursor,
          item_count: ingest_result.processed_count,
          message: sync_summary_message(ingest_result),
          final:
        )
      end

      enqueue_next_page(connection, result.next_cursor, limit, page) unless final
    rescue StandardError => e
      circuit_broken = record_sync_failure(connection, e, cursor)
      raise unless circuit_broken
    end

    private

    # Re-checks the connection's own current state (not the possibly-stale
    # in-memory `connection` this job instance loaded) before scheduling the
    # next page: a circuit-break or manual suspend that happened concurrently
    # (e.g. an admin acting on a different page's failure) must stop the
    # chain, not just the specific job instance that observed it. Also caps
    # pages per dispatch chain as a hard backstop independent of the cursor
    # logic itself.
    def enqueue_next_page(connection, cursor, limit, page) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      if page >= MAX_PAGES_PER_DISPATCH
        Rails.logger.warn(
          '[BetterTogether::Federation] FederatedContentPullJob stopping for connection ' \
          "#{connection.id} - hit MAX_PAGES_PER_DISPATCH (#{MAX_PAGES_PER_DISPATCH}) with cursor still present"
        )
        return
      end

      fresh = connection.class.find_by(id: connection.id)
      return if fresh.nil? || !fresh.active? || fresh.sync_backoff_active?

      self.class.set(wait: rand(NEXT_PAGE_DELAY).seconds).perform_later(
        platform_connection_id: connection.id,
        cursor:,
        limit:,
        page: page + 1
      )
    end

    # Returns true if this failure tripped the circuit breaker (see
    # PlatformConnectionSyncTracking#mark_sync_failed!) so `perform` can stop
    # re-raising once we've suspended the connection ourselves - letting
    # Sidekiq's default retry schedule keep firing after that point would
    # just re-hit the same suspended connection with no chance of success
    # (this is how the 2026-09 token-failure RuntimeError reached a 690-count
    # Sentry issue - every retry re-raised and Sidekiq kept scheduling more).
    def record_sync_failure(connection, error, cursor)
      connection&.reload&.mark_sync_failed!(
        message: error.message,
        cursor:,
        retry_after: error.try(:retry_after)
      )
    rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordNotFound
      # Connection was deleted or another worker updated it between our reload and save.
      false
    end

    def sync_summary_message(result)
      return '' if result.conflict_count.to_i.zero?

      I18n.t('better_together.federation.ingest.sync_summary', count: result.conflict_count)
    end
  end
end
