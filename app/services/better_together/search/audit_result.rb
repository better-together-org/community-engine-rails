# frozen_string_literal: true

module BetterTogether
  module Search
    # Overall backend audit result.
    AuditResult = Struct.new(
      :backend,
      :configured,
      :available,
      :status,
      :generated_at,
      :entry_results,
      :unmanaged_model_names,
      :report_labels,
      :capabilities
    ) do
      def entries
        entry_results
      end

      def collection_label
        report_labels&.fetch(:collection, 'Search Stores') || 'Search Stores'
      end

      def identifier_label
        report_labels&.fetch(:identifier, 'Store') || 'Store'
      end

      def documents_label
        report_labels&.fetch(:documents, 'Searchable Records') || 'Searchable Records'
      end

      def size_label
        report_labels&.fetch(:size, 'Store Size') || 'Store Size'
      end

      def supports_store_size?
        capabilities&.fetch(:store_size, false) || false
      end

      def supports_existence_checks?
        capabilities&.fetch(:existence_checks, false) || false
      end

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
        summary_json.merge(entries: entries.map(&:as_json))
      end

      def summary_json
        {
          backend:,
          configured:,
          available:,
          status:,
          generated_at: generated_at.iso8601,
          unmanaged_model_names:,
          report_labels:,
          capabilities:,
          total_db_count:,
          total_document_count:,
          total_drift_count:,
          healthy: healthy?
        }
      end
    end
  end
end
