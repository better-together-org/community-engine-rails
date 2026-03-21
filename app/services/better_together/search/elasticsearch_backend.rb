# frozen_string_literal: true

module BetterTogether
  module Search
    # Elasticsearch-backed search operations.
    class ElasticsearchBackend < BaseBackend
      SEARCH_TIMEOUT_ERROR = 'backend_unreachable'

      def backend_key
        :elasticsearch
      end

      def configured?
        ENV['ELASTICSEARCH_URL'].present? || ENV['ES_HOST'].present? || ENV['ES_PORT'].present?
      end

      def available?
        configured? && client.present?
      rescue StandardError
        false
      end

      def search(query)
        return empty_result(status: :disabled) unless configured?

        response = Elasticsearch::Model.search(build_query(query), Registry.global_search_models)
        suggestions = (response.response.dig('suggest', 'suggestions') || []).flat_map do |entry|
          entry.fetch('options', []).map { |option| option['text'] }
        end

        SearchResult.new(
          records: response.records.to_a,
          suggestions:,
          status: :ok,
          backend: backend_key
        )
      rescue StandardError => e
        SearchResult.new(
          records: [],
          suggestions: [],
          status: :unreachable,
          backend: backend_key,
          error: "#{e.class}: #{e.message}"
        )
      end

      def create_index(entry)
        return false unless configured?
        return true if index_exists?(entry)

        entry.model_class.create_elastic_index!
        true
      rescue StandardError
        false
      end

      def ensure_index(entry)
        return false unless configured?

        create_index(entry)
      end

      def delete_index(entry)
        return unless index_exists?(entry)

        entry.model_class.delete_elastic_index!
      end

      def refresh_index(entry)
        return unless index_exists?(entry)

        entry.model_class.refresh_elastic_index!
      end

      def import_model(entry, args = {})
        ensure_index(entry)
        entry.model_class.elastic_import(args)
      end

      def index_exists?(entry)
        return false unless available?

        client.indices.exists(index: entry.index_name)
      rescue StandardError
        false
      end

      def document_count(entry)
        return 0 unless index_exists?(entry)

        client.count(index: entry.index_name).fetch('count', 0)
      rescue StandardError
        0
      end

      def index_stats(entry)
        return {} unless index_exists?(entry)

        index_stats = client.indices.stats(index: entry.index_name)
        indices_hash = index_stats.fetch('indices', {})
        indices_hash[entry.index_name] || {}
      rescue StandardError
        {}
      end

      def index_record(record)
        record.__elasticsearch__.index_document
      end

      def delete_record(record)
        record.__elasticsearch__.delete_document
      end

      private

      def client
        Elasticsearch::Model.client
      end

      def empty_result(status:)
        SearchResult.new(records: [], suggestions: [], status:, backend: backend_key)
      end

      def build_query(query)
        {
          query: {
            bool: {
              must: [
                {
                  multi_match: {
                    query: query,
                    type: 'best_fields'
                  }
                }
              ]
            }
          },
          suggest: {
            text: query,
            suggestions: {
              term: {
                field: 'name',
                suggest_mode: 'always'
              }
            }
          }
        }
      end
    end
  end
end
