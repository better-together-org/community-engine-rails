# frozen_string_literal: true

module BetterTogether
  module Search
    # Postgres-native search backend backed by pg_search scopes where available,
    # with a database fallback for models that have not been upgraded yet.
    class PgSearchBackend < DatabaseBackend
      def backend_key
        :pg_search
      end

      def search(query)
        normalized_terms = normalize_terms(query)
        return empty_result(status: :idle) if normalized_terms.empty?

        build_search_result(
          Registry.entries.flat_map do |entry|
            pg_search_matches(entry, query)
          end
        )
      rescue StandardError => e
        unreachable_result(e)
      end

      private

      def pg_search_matches(entry, query)
        model_class = entry.model_class
        return score_matching_records(entry, normalize_terms(query)) unless model_class.respond_to?(:pg_search_query)

        model_class.pg_search_query(query).limit(50).map do |record|
          {
            record:,
            score: record.try(:pg_search_rank).to_f
          }
        end
      end
    end
  end
end
