# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Shared seed ingest seam for importing canonical seeds and optional post-processing.
    class Ingest
      Result = Data.define(:seed_record, :payload, :imported_record)

      def self.call(seed_data:, connection: nil, record_importer: nil, platform: nil)
        new(seed_data:, connection:, record_importer:, platform:).call
      end

      def initialize(seed_data:, connection:, record_importer:, platform: nil)
        @seed_data = seed_data
        @platform = platform
        @connection = connection
        @record_importer = record_importer
      end

      def call
        seed = ::BetterTogether::Seed.import_or_update!(seed_data, platform:)
        payload = seed.payload_data
        imported_record = import_record(seed, payload)

        Result.new(seed, payload, imported_record)
      end

      private

      attr_reader :seed_data, :connection, :record_importer, :platform

      def import_record(seed, payload)
        return nil unless record_importer

        record_importer.call(seed:, payload:, connection:)
      end
    end
  end
end
