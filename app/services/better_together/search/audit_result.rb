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
      :unmanaged_model_names
    ) do
      def entries
        entry_results
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
  end
end
