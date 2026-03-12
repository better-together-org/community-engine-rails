# frozen_string_literal: true

module BetterTogether
  class FederatedContentIngestJob < ApplicationJob
    queue_as :platform_sync

    def perform(platform_connection_id:, items:, sync_cursor: nil)
      connection = ::BetterTogether::PlatformConnection.find(platform_connection_id)
      connection.mark_sync_started!(cursor: sync_cursor)

      result = ::BetterTogether::Content::FederatedContentIngestService.call(
        connection:,
        items:
      )

      connection.mark_sync_succeeded!(
        cursor: sync_cursor,
        item_count: result.processed_count
      )

      result
    rescue StandardError => e
      connection&.mark_sync_failed!(
        message: e.message,
        cursor: sync_cursor
      )
      raise
    end
  end
end
