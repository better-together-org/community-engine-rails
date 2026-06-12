# frozen_string_literal: true

module BetterTogether
  module Search
    # Database-backed fallback search used when no external search adapter is active.
    class DatabaseBackend < BaseBackend # rubocop:todo Metrics/ClassLength, Naming/PredicateMethod
      def audit_report_labels
        {
          collection: 'Scopes',
          identifier: 'Scope',
          documents: 'Searchable Records',
          size: 'Store Size'
        }
      end

      def audit_store_identifier(_entry)
        'database_fallback'
      end

      def audit_search_mode(_entry)
        'database_fallback'
      end

      def audit_store_exists?(_entry)
        true
      end

      def backend_key
        :database
      end

      def configured?
        true
      end

      def available?
        true
      end

      def search(query)
        normalized_terms = normalize_terms(query)
        return empty_result(status: :idle) if normalized_terms.empty?

        build_search_result(scored_matches_for(normalized_terms))
      rescue StandardError => e
        unreachable_result(e)
      end

      # rubocop:disable Naming/PredicateMethod
      def create_index(_entry)
        true
      end

      def ensure_index(_entry)
        true
      end

      def delete_index(_entry)
        true
      end

      def refresh_index(_entry)
        true
      end

      def import_model(_entry, _args = {})
        true
      end

      def index_exists?(_entry)
        true
      end

      def document_count(entry)
        entry.db_count
      end

      def index_stats(_entry)
        {}
      end

      def index_record(_record)
        true
      end

      def delete_record(_record)
        true
      end
      # rubocop:enable Naming/PredicateMethod

      protected

      def scored_matches_for(terms)
        Registry.entries.flat_map do |entry|
          score_matching_records(entry, terms)
        end
      end

      def build_search_result(matches)
        ordered_records = matches
                          .sort_by { |match| [-match[:score], match[:record].id.to_i] }
                          .map { |match| match[:record] }

        SearchResult.new(
          records: ordered_records,
          suggestions: [],
          status: :ok,
          backend: backend_key
        )
      end

      def unreachable_result(error)
        SearchResult.new(
          records: [],
          suggestions: [],
          status: :unreachable,
          backend: backend_key,
          error: "#{error.class}: #{error.message}"
        )
      end

      def score_matching_records(entry, terms)
        Array(entry.relation.to_a).filter_map do |record|
          haystack = searchable_text(record)
          next if haystack.blank?
          next unless terms.all? { |term| haystack.include?(term) }

          {
            record:,
            score: score_terms(haystack, terms)
          }
        end
      end

      def searchable_text(record)
        payload = if record.respond_to?(:as_indexed_json)
                    record.as_indexed_json
                  else
                    record.attributes
                  end

        flatten_values(payload).join(' ').downcase
      end

      def flatten_values(value)
        case value
        when Hash
          value.values.flat_map { |item| flatten_values(item) }
        when Array
          value.flat_map { |item| flatten_values(item) }
        when NilClass
          []
        else
          [value.to_s]
        end
      end

      def normalize_terms(query)
        query.to_s.downcase.scan(/[[:alnum:]\-_]+/).uniq
      end

      def score_terms(haystack, terms)
        terms.sum { |term| haystack.scan(term).size }
      end

      def empty_result(status:)
        SearchResult.new(records: [], suggestions: [], status:, backend: backend_key)
      end
    end
  end
end
