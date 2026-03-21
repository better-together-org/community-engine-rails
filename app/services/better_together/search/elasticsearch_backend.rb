# frozen_string_literal: true

module BetterTogether
  module Search
    # Elasticsearch-backed search operations.
    class ElasticsearchBackend < BaseBackend
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

        search_result(build_response(query))
      rescue StandardError => e
        unreachable_result(e)
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

      def build_response(query)
        Elasticsearch::Model.search(ElasticsearchQuery.build(query), Registry.global_search_models)
      end

      def search_result(response)
        SearchResult.new(
          records: response.records.to_a,
          suggestions: ElasticsearchQuery.suggestions(response),
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

      def empty_result(status:)
        SearchResult.new(records: [], suggestions: [], status:, backend: backend_key)
      end
    end
  end
end
