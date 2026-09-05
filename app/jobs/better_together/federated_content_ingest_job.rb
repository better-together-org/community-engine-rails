# frozen_string_literal: true

module BetterTogether
  # Background job that ingests federated content seeds from remote platforms.
  #
  # NOTE: Seeds are serialised into the job payload. For large batches, callers should
  # use FederatedContentPullJob which fetches seeds on-demand and never serialises them.
  # This job accepts seeds directly only for small, bounded payloads (e.g. push delivery).
  class FederatedContentIngestJob < ApplicationJob
    queue_as :platform_sync

    MAX_SEEDS_PER_JOB = 50

    def perform(platform_connection_id:, seeds:, sync_cursor: nil)
      raise ArgumentError, oversized_seeds_message(seeds.size) if seeds.size > MAX_SEEDS_PER_JOB

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
      connection.mark_sync_succeeded!(
        cursor:,
        item_count: result.processed_count,
        message: sync_summary_message(result)
      )
    end

    def sync_summary_message(result)
      return '' if result.conflict_count.to_i.zero?

      I18n.t(
        'better_together.federation.ingest.sync_summary',
        count: result.conflict_count
      )
    end

    def oversized_seeds_message(seed_count)
      I18n.t(
        'better_together.federation.ingest.errors.seeds_payload_too_large',
        count: seed_count,
        max_count: MAX_SEEDS_PER_JOB
      )
    end
  end
end
