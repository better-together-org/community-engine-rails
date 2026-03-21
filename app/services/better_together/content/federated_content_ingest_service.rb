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
        :planting
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

        batches = process_seeds
        result = build_result(batches, planting)
        planting.mark_completed!(planting_summary(result))
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

      def process_seeds
        batches = empty_seed_batches
        Current.set(platform: connection.target_platform) do
          seeds.each { |seed_data| classify_seed(seed_data, batches) }
        end
        batches
      end

      def empty_seed_batches
        { imported_seeds: [], imported_records: [], unsupported_seeds: [] }
      end

      def classify_seed(seed_data, batches)
        seed, record = ::BetterTogether::Seeds::FederatedSeedIngestor.call(connection:, seed_data:)
        if record.nil?
          batches[:unsupported_seeds] << seed_data
        else
          batches[:imported_seeds] << seed
          batches[:imported_records] << record
        end
      end

      def build_result(batches, planting)
        Result.new(
          connection:,
          processed_count: batches[:imported_records].length,
          imported_seeds: batches[:imported_seeds],
          imported_records: batches[:imported_records],
          unsupported_seeds: batches[:unsupported_seeds],
          planting:
        )
      end

      def planting_summary(result)
        {
          'processed_count' => result.processed_count,
          'unsupported_count' => result.unsupported_seeds.length
        }
      end
    end
  end
end
