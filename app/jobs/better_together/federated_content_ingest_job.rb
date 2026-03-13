# frozen_string_literal: true

module BetterTogether
  # Background job that ingests federated content seeds from remote platforms.
  class FederatedContentIngestJob < ApplicationJob
    queue_as :platform_sync

    def perform(platform_connection_id:, seeds:, sync_cursor: nil)
      connection = ::BetterTogether::PlatformConnection.find(platform_connection_id)
      connection.mark_sync_started!(cursor: sync_cursor)
      result = run_ingest_service(connection, seeds)
      record_sync_success(connection, result, sync_cursor)
      result
    rescue StandardError => e
      connection&.mark_sync_failed!(message: e.message, cursor: sync_cursor)
      raise
    end

    private

    def run_ingest_service(connection, seeds)
      ::BetterTogether::Content::FederatedContentIngestService.call(connection:, seeds:)
    end

    def record_sync_success(connection, result, cursor)
      connection.mark_sync_succeeded!(cursor:, item_count: result.processed_count)
    end
  end
end
