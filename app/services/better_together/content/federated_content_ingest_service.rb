# frozen_string_literal: true

module BetterTogether
  module Content
    # Imports a batch of mirrored content records through the federated mirror services.
    class FederatedContentIngestService
      Result = Struct.new(
        :connection,
        :processed_count,
        :imported_seeds,
        :imported_records,
        :unsupported_seeds,
        :planting,
        keyword_init: true
      )

      def self.call(connection:, seeds: nil, items: nil)
        new(connection:, seeds: seeds || items).call
      end

      def initialize(connection:, seeds:)
        @connection = connection
        @seeds = Array(seeds)
      end

      def call
        raise ArgumentError, 'connection is required' unless connection

        planting = create_planting!
        planting.mark_started!

        imported_seeds = []
        imported_records = []
        unsupported_seeds = []

        Current.set(platform: connection.target_platform) do
          seeds.each do |seed_data|
            seed, record = ::BetterTogether::Seeds::FederatedSeedIngestor.call(
              connection:,
              seed_data:
            )

            if record.nil?
              unsupported_seeds << seed_data
              next
            end

            imported_seeds << seed
            imported_records << record
          end
        end

        result = Result.new(
          connection:,
          processed_count: imported_records.length,
          imported_seeds:,
          imported_records: imported_records,
          unsupported_seeds: unsupported_seeds,
          planting:
        )
        planting.mark_completed!(
          'processed_count' => result.processed_count,
          'unsupported_count' => result.unsupported_seeds.length
        )
        result
      rescue StandardError => e
        planting&.mark_failed!(e)
        raise
      end

      private

      attr_reader :connection, :seeds

      def create_planting!
        ::BetterTogether::SeedPlanting.create!(
          planting_type: :federated_tending,
          source: connection.source_platform.resolved_host_url,
          privacy: 'private',
          metadata: {
            'source_platform_id' => connection.source_platform.id,
            'target_platform_id' => connection.target_platform.id,
            'seed_count' => seeds.length
          }
        )
      end
    end
  end
end
