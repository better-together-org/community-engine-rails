# frozen_string_literal: true

module BetterTogether
  class FederatedContentPullJob < ApplicationJob
    queue_as :platform_sync

    def perform(platform_connection_id:, cursor: nil, limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT)
      connection = ::BetterTogether::PlatformConnection.find(platform_connection_id)
      connection.mark_sync_started!(cursor:)

      result = ::BetterTogether::FederatedContentPullService.call(
        connection:,
        cursor:,
        limit:
      )

      return if result.items.blank?

      ::BetterTogether::FederatedContentIngestJob.perform_later(
        platform_connection_id: connection.id,
        items: result.items,
        sync_cursor: result.next_cursor
      )
    rescue StandardError => e
      connection&.mark_sync_failed!(
        message: e.message,
        cursor:
      )
      raise
    end
  end
end
