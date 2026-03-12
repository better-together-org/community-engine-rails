# frozen_string_literal: true

module BetterTogether
  module Content
    # Imports a batch of mirrored content records through the federated mirror services.
    class FederatedContentIngestService
      IMPORTER_MAP = {
        'post' => ::BetterTogether::Content::FederatedPostMirrorService,
        'page' => ::BetterTogether::Content::FederatedPageMirrorService,
        'event' => ::BetterTogether::FederatedEventMirrorService
      }.freeze

      Result = Struct.new(
        :connection,
        :processed_count,
        :imported_records,
        :unsupported_items,
        keyword_init: true
      )

      def self.call(connection:, items:)
        new(connection:, items:).call
      end

      def initialize(connection:, items:)
        @connection = connection
        @items = Array(items)
      end

      def call
        raise ArgumentError, 'connection is required' unless connection

        imported_records = []
        unsupported_items = []

        Current.set(platform: connection.target_platform) do
          items.each do |item|
            importer_class = importer_for(item)

            if importer_class.nil?
              unsupported_items << item
              next
            end

            imported_records << importer_class.new(
              connection:,
              remote_attributes: item.fetch(:attributes, {}),
              remote_id: item.fetch(:id),
              preserve_remote_uuid: item[:preserve_remote_uuid],
              source_updated_at: item[:source_updated_at]
            ).call
          end
        end

        Result.new(
          connection:,
          processed_count: imported_records.length,
          imported_records: imported_records,
          unsupported_items: unsupported_items
        )
      end

      private

      attr_reader :connection, :items

      def importer_for(item)
        IMPORTER_MAP[normalize_type(item[:type])]
      end

      def normalize_type(type)
        type.to_s.strip.downcase
      end
    end
  end
end
