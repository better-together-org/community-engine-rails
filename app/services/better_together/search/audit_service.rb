# frozen_string_literal: true

module BetterTogether
  module Search
    # Produces a normalized audit of DB-to-search-index parity and backend health.
    class AuditService
      # Per-index audit details.
      EntryResult = Struct.new(
        :model_name,
        :index_name,
        :db_count,
        :document_count,
        :drift_count,
        :status,
        :index_exists,
        :primary_shards,
        :replica_shards,
        :store_size_bytes,
        keyword_init: true
      ) do
        def store_size_human
          return '0 Bytes' if store_size_bytes.to_i.zero?

          ActiveSupport::NumberHelper.number_to_human_size(store_size_bytes)
        end

        def as_json(*)
          {
            model_name:,
            index_name:,
            db_count:,
            document_count:,
            drift_count:,
            status:,
            index_exists:,
            primary_shards:,
            replica_shards:,
            store_size_bytes:,
            store_size_human:
          }
        end
      end

      # Overall backend audit result.
      Result = Struct.new(
        :backend,
        :configured,
        :available,
        :status,
        :generated_at,
        :entries,
        :unmanaged_model_names,
        keyword_init: true
      ) do
        def total_db_count
          entries.sum(&:db_count)
        end

        def total_document_count
          entries.sum(&:document_count)
        end

        def total_drift_count
          entries.sum(&:drift_count)
        end

        def healthy?
          status == :ok && total_drift_count.zero? && entries.all? { |entry| entry.status == :healthy }
        end

        def as_json(*)
          {
            backend:,
            configured:,
            available:,
            status:,
            generated_at: generated_at.iso8601,
            unmanaged_model_names:,
            total_db_count:,
            total_document_count:,
            total_drift_count:,
            healthy: healthy?,
            entries: entries.map(&:as_json)
          }
        end
      end

      def initialize(backend: BetterTogether::Search.backend)
        @backend = backend
      end

      def call
        Result.new(
          backend: @backend.backend_key,
          configured: @backend.configured?,
          available: @backend.available?,
          status: overall_status,
          generated_at: Time.current,
          entries: build_entries,
          unmanaged_model_names: BetterTogether::Search::Registry.unmanaged_searchable_models.map(&:name).sort
        )
      end

      private

      def overall_status
        return :disabled unless @backend.configured?
        return :unreachable unless @backend.available?

        :ok
      end

      def build_entries
        BetterTogether::Search::Registry.entries.map do |entry|
          build_entry(entry)
        end
      end

      def build_entry(entry)
        exists = @backend.index_exists?(entry)
        stats = @backend.index_stats(entry)
        total_stats = stats.fetch('total', {})
        store_stats = total_stats.fetch('store', {})

        db_count = entry.db_count
        document_count = exists ? @backend.document_count(entry) : 0
        drift_count = (db_count - document_count).abs

        EntryResult.new(
          model_name: entry.model_name,
          index_name: entry.index_name,
          db_count:,
          document_count:,
          drift_count:,
          status: entry_status(exists:, drift_count:),
          index_exists: exists,
          primary_shards: stats.fetch('primaries', {}).fetch('docs', {}).fetch('count', nil),
          replica_shards: total_stats.fetch('docs', {}).fetch('count', nil),
          store_size_bytes: store_stats.fetch('size_in_bytes', 0)
        )
      rescue StandardError
        EntryResult.new(
          model_name: entry.model_name,
          index_name: entry.index_name,
          db_count: entry.db_count,
          document_count: 0,
          drift_count: entry.db_count,
          status: fallback_entry_status,
          index_exists: false,
          primary_shards: nil,
          replica_shards: nil,
          store_size_bytes: 0
        )
      end

      def entry_status(exists:, drift_count:)
        return :disabled unless @backend.configured?
        return :unreachable unless @backend.available?
        return :missing unless exists
        return :drifted if drift_count.positive?

        :healthy
      end

      def fallback_entry_status
        return :disabled unless @backend.configured?

        :unreachable
      end
    end
  end
end
