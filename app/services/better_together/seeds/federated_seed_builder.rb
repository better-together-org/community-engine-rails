# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Compatibility wrapper over Seeds::Builder for legacy federated export callers.
    class FederatedSeedBuilder
      VERSION = '1.0'

      def self.call(record:, connection:, lane: 'platform_shared', origin_metadata: {})
        new(record:, connection:, lane:, origin_metadata:).call
      end

      def initialize(record:, connection:, lane:, origin_metadata: {})
        @record = record
        @connection = connection
        @lane = lane
        @origin_metadata = origin_metadata
      end

      def call
        ::BetterTogether::Seeds::Builder.call(
          subject: record,
          profile: lane,
          context: {
            connection:,
            origin_metadata:
          },
          lane:,
          persist: false,
          version: VERSION
        ).seed_hash
      end

      private

      attr_reader :record, :connection, :lane, :origin_metadata
    end
  end
end
