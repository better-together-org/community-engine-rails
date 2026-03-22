# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Persists an imported seed envelope and dispatches it to the mirror layer.
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
        seed = ::BetterTogether::Seed.import_or_update!(seed_data)
        payload = seed.payload_data
        importer_class = IMPORTER_MAP[payload[:type].to_s]
        return [seed, nil] if importer_class.nil?

        record = importer_class.new(
          connection:,
          remote_attributes: payload[:attributes] || {},
          remote_id: payload.fetch(:id),
          preserve_remote_uuid: payload[:preserve_remote_uuid],
          source_updated_at: payload[:source_updated_at]
        ).call

        [seed, record]
      end

      private

      attr_reader :connection, :seed_data
    end
  end
end
