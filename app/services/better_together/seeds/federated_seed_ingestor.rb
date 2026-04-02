# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Compatibility wrapper over Seeds::Ingest for mirrored-content callers.
    class FederatedSeedIngestor
      IMPORTER_MAP = {
        'post' => ::BetterTogether::Content::FederatedPostMirrorService,
        'page' => ::BetterTogether::Content::FederatedPageMirrorService,
        'event' => ::BetterTogether::FederatedEventMirrorService
      }.freeze

      def self.call(connection:, seed_data:)
        new(connection:, seed_data:).call
      end

      def initialize(connection:, seed_data:)
        @connection = connection
        @seed_data = seed_data
      end

      def call
        result = ::BetterTogether::Seeds::Ingest.call(
          seed_data: seed_data,
          connection: connection,
          record_importer: method(:import_record)
        )

        [result.seed_record, result.imported_record]
      end

      private

      attr_reader :connection, :seed_data

      def import_record(payload:, connection:, **)
        importer_class = IMPORTER_MAP[payload[:type].to_s]
        return nil if importer_class.nil?

        importer_class.new(
          connection: connection,
          remote_attributes: payload[:attributes] || {},
          remote_id: payload.fetch(:id),
          preserve_remote_uuid: payload[:preserve_remote_uuid],
          source_updated_at: payload[:source_updated_at]
        ).call
      end
    end
  end
end
