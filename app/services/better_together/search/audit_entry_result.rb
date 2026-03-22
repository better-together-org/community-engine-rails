# frozen_string_literal: true

module BetterTogether
  module Search
    # Per-index audit details.
    AuditEntryResult = Struct.new(
      :model_name,
      :index_name,
      :db_count,
      :document_count,
      :drift_count,
      :status,
      :index_exists,
      :primary_shards,
      :replica_shards,
      :store_size_bytes
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
  end
end
