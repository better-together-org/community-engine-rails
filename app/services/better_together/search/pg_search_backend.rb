# frozen_string_literal: true

module BetterTogether
  module Search
    # Postgres-native search backend backed by pg_search scopes where available,
    # with a database fallback for models that have not been upgraded yet.
    class PgSearchBackend < DatabaseBackend
      def audit_store_identifier(entry)
        return entry.search_scope_name.to_s if entry.pg_search_enabled?

        super
      end

      def audit_search_mode(entry)
        return 'pg_search' if entry.pg_search_enabled?

        super
      end

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
        return score_matching_records(entry, normalize_terms(query)) unless entry.pg_search_enabled?

        entry.search_relation(query).limit(50).map do |record|
          {
            record:,
            score: record.try(:pg_search_rank).to_f
          }
        end
      end
    end
  end
end
