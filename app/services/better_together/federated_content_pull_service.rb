# frozen_string_literal: true

module BetterTogether
  # Pulls one content-feed batch from a federated peer platform.
  class FederatedContentPullService
    DEFAULT_LIMIT = 50

    Result = Struct.new(
      :connection,
      :seeds,
      :next_cursor
    ) do
      def items
        seeds
      end
    end

    def self.call(connection:, cursor: nil, limit: DEFAULT_LIMIT)
      new(connection:, cursor:, limit:).call
    end

    def initialize(connection:, cursor: nil, limit: DEFAULT_LIMIT)
      @connection = connection
      @cursor = cursor
      @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
    end

    def call
      resolution.adapter_class.call(
        connection:,
        cursor:,
        limit:
      )
    end

    private

    attr_reader :connection, :cursor, :limit

    def resolution
      @resolution ||= ::BetterTogether::Federation::Transport::TransportResolver.call(connection:)
    end
  end
end
