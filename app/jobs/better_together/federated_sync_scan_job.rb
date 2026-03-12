# frozen_string_literal: true

module BetterTogether
  class FederatedSyncScanJob < ApplicationJob
    queue_as :platform_sync

    def perform(limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT)
      ::BetterTogether::PlatformConnection.active.find_each do |connection|
        next unless connection.mirrored_content_enabled?
        next unless connection.api_read_enabled?

        ::BetterTogether::FederatedContentPullJob.perform_later(
          platform_connection_id: connection.id,
          cursor: connection.sync_cursor.presence,
          limit:
        )
      end
    end
  end
end
