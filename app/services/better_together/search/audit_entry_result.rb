# frozen_string_literal: true

module BetterTogether
  module Search
    # Per-index audit details.
    AuditEntryResult = Struct.new(
      :model_name,
      :store_identifier,
      :index_name,
      :db_count,
      :document_count,
      :drift_count,
      :status,
      :search_mode,
      :store_exists,
      :index_exists,
      :primary_shards,
      :replica_shards,
      :store_size_bytes
    ) do
      def store_identifier
        self[:store_identifier] || index_name
      end

      def search_mode
        self[:search_mode]
      end

      def store_exists
        return self[:store_exists] unless self[:store_exists].nil?

        index_exists
      end

      def index_exists
        value = self[:index_exists]
        return value unless value.nil?

        self[:store_exists]
      end

      def store_size_human
        return '0 Bytes' if store_size_bytes.to_i.zero?

        ActiveSupport::NumberHelper.number_to_human_size(store_size_bytes)
      end

      def as_json(*)
        count_json.merge(
          model_name:,
          store_identifier:,
          index_name:,
          status:,
          search_mode:,
          store_exists:,
          index_exists:,
          store_size_human:
        )
      end

      def count_json
        {
          db_count:,
          document_count:,
          drift_count:,
          primary_shards:,
          replica_shards:,
          store_size_bytes:
        }
      end
    end
  end
end
