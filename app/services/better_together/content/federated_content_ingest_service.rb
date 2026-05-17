# frozen_string_literal: true

module BetterTogether
  module Content
    # Imports a batch of mirrored content records through the federated mirror services.
    # rubocop:disable Metrics/ClassLength -- Ingest orchestration and conflict reporting
    #   are intentionally kept together for auditability of a single sync batch.
    class FederatedContentIngestService
      IMPORTER_MAP = {
        'post' => ::BetterTogether::Content::FederatedPostMirrorService,
        'page' => ::BetterTogether::Content::FederatedPageMirrorService,
        'event' => ::BetterTogether::FederatedEventMirrorService
      }.freeze

      Result = Struct.new(
        :connection,
        :processed_count,
        :imported_seeds,
        :imported_records,
        :unsupported_seeds,
        :conflicted_seeds,
        :conflict_count,
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
        persist_conflict_metadata!(planting, result)
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
        { imported_seeds: [], imported_records: [], unsupported_seeds: [], conflicted_seeds: [] }
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def classify_seed(seed_data, batches)
        result = ::BetterTogether::Seeds::Ingest.call(
          seed_data: seed_data,
          connection: connection,
          record_importer: method(:import_record)
        )
        seed = result.seed_record
        record = result.imported_record

        if record.nil?
          batches[:unsupported_seeds] << seed_data
        else
          batches[:imported_seeds] << seed
          batches[:imported_records] << record
        end
      rescue ActiveRecord::RecordInvalid => e
        conflict = build_conflict_summary(seed_data, e)
        raise unless conflict

        batches[:conflicted_seeds] << conflict
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def build_result(batches, planting)
        Result.new(
          connection:,
          processed_count: batches[:imported_records].length,
          imported_seeds: batches[:imported_seeds],
          imported_records: batches[:imported_records],
          unsupported_seeds: batches[:unsupported_seeds],
          conflicted_seeds: batches[:conflicted_seeds],
          conflict_count: batches[:conflicted_seeds].length,
          planting:
        )
      end

      def planting_summary(result)
        {
          'processed_count' => result.processed_count,
          'unsupported_count' => result.unsupported_seeds.length,
          'conflict_count' => result.conflict_count
        }
      end

      def persist_conflict_metadata!(planting, result)
        planting.update!(
          metadata: planting.metadata.merge(
            'conflict_count' => result.conflict_count,
            'conflicted_seeds' => result.conflicted_seeds
          )
        )
      end

      # rubocop:disable Metrics/AbcSize
      def build_conflict_summary(seed_data, error)
        payload = extract_payload(seed_data)
        return unless mirrored_collision_error?(payload, error)

        model_class = importer_model_for(payload[:type])
        existing_record = conflicting_record_for(model_class, payload, error.record)

        {
          'seed_type' => payload[:type].to_s,
          'remote_id' => payload[:id].to_s,
          'remote_identifier' => payload.dig(:attributes, :identifier).presence,
          'source_platform_identifier' => connection.source_platform.identifier,
          'target_platform_identifier' => connection.target_platform.identifier,
          'existing_local_identifier' => existing_record&.identifier,
          'validation_messages' => error.record.errors.full_messages,
          'conflict_kind' => 'mirrored_identifier_collision'
        }
      end
      # rubocop:enable Metrics/AbcSize

      def mirrored_collision_error?(payload, error)
        IMPORTER_MAP.key?(payload[:type].to_s) &&
          importer_model_for(payload[:type]) == error.record.class &&
          collision_validation?(error)
      end

      def collision_validation?(error)
        details = error.record.errors.details

        taken_error?(details[:identifier]) || taken_error?(details[:slug])
      end

      def taken_error?(details)
        Array(details).any? { |detail| detail[:error] == :taken }
      end

      def extract_payload(seed_data)
        seed_data.deep_symbolize_keys.fetch(:better_together).fetch(:payload).with_indifferent_access
      end

      def importer_model_for(type)
        case type.to_s
        when 'post' then ::BetterTogether::Post
        when 'page' then ::BetterTogether::Page
        when 'event' then ::BetterTogether::Event
        end
      end

      # rubocop:disable Metrics/MethodLength
      def conflicting_record_for(model_class, payload, record)
        importer = IMPORTER_MAP.fetch(payload[:type].to_s).new(
          connection: connection,
          remote_attributes: payload[:attributes] || {},
          remote_id: payload.fetch(:id),
          preserve_remote_uuid: payload[:preserve_remote_uuid],
          source_updated_at: payload[:source_updated_at]
        )

        importer.send(
          :existing_identifier_conflict_for,
          model_class,
          remote_identifier: payload.dig(:attributes, :identifier),
          remote_id: payload.fetch(:id),
          content_type: payload[:type].to_s,
          exclude_id: record.id
        )
      end
      # rubocop:enable Metrics/MethodLength

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
    # rubocop:enable Metrics/ClassLength
  end
end
