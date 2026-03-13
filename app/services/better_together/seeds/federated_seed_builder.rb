# frozen_string_literal: true

require 'digest'

module BetterTogether
  module Seeds
    # Builds a portable CE seed envelope for federated export.
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
        {
          BetterTogether::Seed::DEFAULT_ROOT_KEY => {
            version: VERSION,
            seed: seed_metadata,
            payload: payload
          }
        }
      end

      private

      attr_reader :record, :connection, :lane, :origin_metadata

      def seed_metadata
        {
          type: 'BetterTogether::Seed',
          identifier: identifier,
          created_by: 'FederatedExport',
          created_at: record.updated_at.utc.iso8601,
          description: "Federated seed for #{record.class.name} #{record.id}",
          origin: origin_attributes,
          seedable_type: record.class.name,
          seedable_id: record.id
        }
      end

      def origin_attributes
        {
          lane:,
          source_platform_id: connection.source_platform.id,
          source_platform_identifier: connection.source_platform.identifier,
          source_platform_url: connection.source_platform.resolved_host_url,
          visibility: serialized_attributes[:privacy],
          content_type: serialized_type
        }.merge(origin_metadata)
      end

      def payload
        {
          lane:,
          type: serialized_type,
          id: record.id,
          preserve_remote_uuid: true,
          source_updated_at: record.updated_at.iso8601,
          attributes: serialized_attributes
        }
      end

      def identifier
        digest = Digest::SHA256.hexdigest(
          [connection.source_platform.id, record.class.name, record.id, lane].join(':')
        )
        "seed-#{serialized_type}-#{digest.first(24)}"
      end

      def serialized_type
        case record
        when ::BetterTogether::Post then 'post'
        when ::BetterTogether::Page then 'page'
        when ::BetterTogether::Event then 'event'
        else
          raise ArgumentError, "unsupported record type: #{record.class.name}"
        end
      end

      def serialized_attributes
        case record
        when ::BetterTogether::Post then FederatedSeedAttributes.post_attributes(record)
        when ::BetterTogether::Page then FederatedSeedAttributes.page_attributes(record)
        when ::BetterTogether::Event then FederatedSeedAttributes.event_attributes(record)
        end
      end
    end
  end
end
