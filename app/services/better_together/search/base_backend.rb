# frozen_string_literal: true

module BetterTogether
  module Search
    # Minimal contract for pluggable search backends.
    class BaseBackend
      def audit_report_labels
        {
          collection: 'Search Stores',
          identifier: 'Store',
          documents: 'Searchable Records',
          size: 'Store Size'
        }
      end

      def audit_capabilities
        {
          store_size: false,
          existence_checks: false
        }
      end

      def audit_store_identifier(entry)
        entry.model_name
      end

      def audit_search_mode(_entry)
        backend_key.to_s
      end

      def audit_store_exists?(entry)
        index_exists?(entry)
      end

      def backend_key
        raise NotImplementedError
      end

      def configured?
        raise NotImplementedError
      end

      def available?
        raise NotImplementedError
      end

      def search(_query)
        raise NotImplementedError
      end

      def create_index(_entry)
        raise NotImplementedError
      end

      def ensure_index(_entry)
        raise NotImplementedError
      end

      def delete_index(_entry)
        raise NotImplementedError
      end

      def refresh_index(_entry)
        raise NotImplementedError
      end

      def import_model(_entry, _args = {})
        raise NotImplementedError
      end

      def index_exists?(_entry)
        raise NotImplementedError
      end

      def document_count(_entry)
        raise NotImplementedError
      end

      def index_stats(_entry)
        raise NotImplementedError
      end

      def index_record(_record)
        raise NotImplementedError
      end

      def delete_record(_record)
        raise NotImplementedError
      end
    end
  end
end
