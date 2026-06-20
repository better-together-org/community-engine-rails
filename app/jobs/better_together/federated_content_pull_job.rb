# frozen_string_literal: true

module BetterTogether
  # Pulls a paginated batch of federated content from a remote platform,
  # ingests it inline, then enqueues the next page if a cursor is returned.
  # Seeds are never serialised into job arguments to avoid large Redis payloads.
  class FederatedContentPullJob < ApplicationJob # rubocop:disable Metrics/ClassLength
    queue_as :platform_sync
    discard_on ActiveRecord::StaleObjectError

    def perform(platform_connection_id:, cursor: nil, limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      connection = ::BetterTogether::PlatformConnection.find(platform_connection_id)
      connection.mark_sync_started!(cursor:)

      result = ::BetterTogether::FederatedContentPullService.call(
        connection:,
        cursor:,
        limit:
      )

      if result.seeds.blank?
        connection.mark_sync_succeeded!(cursor: result.next_cursor)
        return
      end

      ingest_result = ::BetterTogether::Content::FederatedContentIngestService.call(
        connection:,
        seeds: result.seeds
      )
      connection.mark_sync_succeeded!(
        cursor: result.next_cursor,
        item_count: ingest_result.processed_count,
        message: sync_summary_message(ingest_result)
      )

      # Enqueue the next page if more content is available
      if result.next_cursor.present?
        self.class.perform_later(
          platform_connection_id: connection.id,
          cursor: result.next_cursor,
          limit:
        )
      end
    rescue StandardError => e
      begin
        connection&.reload&.mark_sync_failed!(message: e.message, cursor:)
      rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordNotFound
        # Connection was deleted or another worker updated it between our reload and save.
        nil
      end
      raise
    end

    private

    def sync_summary_message(result)
      return '' if result.conflict_count.to_i.zero?

      I18n.t(
        'better_together.federation.ingest.sync_summary',
        count: result.conflict_count
      )
    end
  end
end
