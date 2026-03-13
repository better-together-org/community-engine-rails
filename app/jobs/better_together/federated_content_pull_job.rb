# frozen_string_literal: true

module BetterTogether
  # Pulls a paginated batch of federated content from a remote platform and
  # enqueues an ingest job. Marks the connection sync state on each outcome.
  class FederatedContentPullJob < ApplicationJob # rubocop:disable Metrics/MethodLength
    queue_as :platform_sync

    def perform(platform_connection_id:, cursor: nil, limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT) # rubocop:disable Metrics/MethodLength
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

      ::BetterTogether::FederatedContentIngestJob.perform_later(
        platform_connection_id: connection.id,
        seeds: result.seeds,
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
