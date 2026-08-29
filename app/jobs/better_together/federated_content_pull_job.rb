# frozen_string_literal: true

module BetterTogether
  # Pulls a paginated batch of federated content from a remote platform,
  # ingests it inline, then enqueues the next page if a cursor is returned.
  # Seeds are never serialised into job arguments to avoid large Redis payloads.
  class FederatedContentPullJob < ApplicationJob # rubocop:disable Metrics/ClassLength
    # Small randomised gap before fetching the next page so a large feed isn't
    # paginated as one tight burst against the remote's per-IP rate limit.
    NEXT_PAGE_DELAY = (2..6)

    queue_as :platform_sync
    discard_on ActiveRecord::StaleObjectError
    # A rate-limited remote is handled by marking the connection failed with a
    # cool-off (honouring Retry-After); the hourly sync scan re-dispatches once
    # sync_backoff_until passes. Retrying the job here would just re-hit the
    # throttle, so drop it rather than run Sidekiq's default retry schedule.
    discard_on ::BetterTogether::Federation::Transport::HttpAdapter::RateLimitedError

    def perform(platform_connection_id:, cursor: nil, limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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

      enqueue_next_page(connection, result.next_cursor, limit) unless final
    rescue StandardError => e
      record_sync_failure(connection, e, cursor)
      raise
    end

    private

    def enqueue_next_page(connection, cursor, limit)
      self.class.set(wait: rand(NEXT_PAGE_DELAY).seconds).perform_later(
        platform_connection_id: connection.id,
        cursor:,
        limit:
      )
    end

    def record_sync_failure(connection, error, cursor)
      connection&.reload&.mark_sync_failed!(
        message: error.message,
        cursor:,
        retry_after: error.try(:retry_after)
      )
    rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordNotFound
      # Connection was deleted or another worker updated it between our reload and save.
      nil
    end

    def sync_summary_message(result)
      return '' if result.conflict_count.to_i.zero?

      I18n.t('better_together.federation.ingest.sync_summary', count: result.conflict_count)
    end
  end
end
