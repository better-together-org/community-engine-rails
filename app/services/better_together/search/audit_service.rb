# frozen_string_literal: true

module BetterTogether
  module Search
    # Produces a normalized audit of DB-to-search-index parity and backend health.
    class AuditService
      EntryResult = BetterTogether::Search::AuditEntryResult
      Result = BetterTogether::Search::AuditResult

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
          entry_results: build_entries,
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
        BetterTogether::Search::Registry.entries.map { |entry| build_entry(entry) }
      end

      def build_entry(entry)
        exists = @backend.index_exists?(entry)
        entry_stats = stats(entry)
        entry_document_count = document_count(entry, exists)
        EntryResult.new(**entry_attributes(entry, exists, entry_stats, entry_document_count))
      rescue StandardError
        fallback_entry(entry)
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

      def fallback_entry(entry)
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

      def entry_attributes(entry, exists, entry_stats, entry_document_count)
        entry_drift_count = drift_count(entry.db_count, entry_document_count)

        {
          model_name: entry.model_name,
          index_name: entry.index_name,
          db_count: entry.db_count,
          document_count: entry_document_count,
          drift_count: entry_drift_count,
          status: entry_status(exists:, drift_count: entry_drift_count),
          index_exists: exists,
          primary_shards: entry_stats.dig('primaries', 'docs', 'count'),
          replica_shards: entry_stats.dig('total', 'docs', 'count'),
          store_size_bytes: entry_stats.dig('total', 'store', 'size_in_bytes') || 0
        }
      end

      def stats(entry)
        @backend.index_stats(entry)
      end

      def document_count(entry, exists)
        exists ? @backend.document_count(entry) : 0
      end

      def drift_count(db_count, document_count)
        (db_count - document_count).abs
      end
    end
  end
end
