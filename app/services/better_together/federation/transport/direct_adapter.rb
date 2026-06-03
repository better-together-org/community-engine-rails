# frozen_string_literal: true

module BetterTogether
  module Federation
    module Transport
      # Fetches a federation feed in-process when both platforms live in the same app.
      class DirectAdapter
        def self.call(connection:, cursor: nil, limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT)
          new(connection:, cursor:, limit:).call
        end

        def initialize(connection:, cursor: nil, limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT)
          @connection = connection
          @cursor = cursor
          @limit = limit
        end

        def call
          export_result = ::BetterTogether::Content::FederatedContentExportService.call(
            connection:,
            cursor:,
            limit:
          )

          ::BetterTogether::FederatedContentPullService::Result.new(
            connection:,
            seeds: export_result.seeds,
            next_cursor: export_result.next_cursor
          )
        end

        private

        attr_reader :connection, :cursor, :limit
      end
    end
  end
end
