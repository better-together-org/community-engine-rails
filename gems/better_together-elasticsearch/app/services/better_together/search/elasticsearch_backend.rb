# frozen_string_literal: true

module BetterTogether
  module Search
    class ElasticsearchBackend < BaseBackend # rubocop:todo Metrics/ClassLength
      def audit_report_labels
        {
          collection: 'Indices',
          identifier: 'Index',
          documents: 'Indexed Documents',
          size: 'Store Size'
        }
      end

      def audit_capabilities
        {
          store_size: true,
          existence_checks: true
        }
      end

      def audit_store_identifier(entry)
        index_name_for(entry)
      end

      def audit_search_mode(_entry)
        'elasticsearch'
      end

      def backend_key
        :elasticsearch
      end

      def configured?
        return false unless BetterTogether::ElasticsearchClientOptions.enabled?

        client.present?
      rescue StandardError
        false
      end

      def available?
        configured? && client.ping
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

        entry.model_class.__elasticsearch__.create_index!
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

        entry.model_class.__elasticsearch__.delete_index!
      rescue StandardError => e
        raise unless missing_index_error?(e)

        nil
      end

      def refresh_index(entry)
        return unless index_exists?(entry)

        entry.model_class.__elasticsearch__.refresh_index!
      end

      def import_model(entry, args = {})
        ensure_index(entry)
        entry.model_class.__elasticsearch__.import(args)
      end

      def index_exists?(entry)
        return false unless available?
        return false unless index_name_for(entry)

        client.indices.exists(index: index_name_for(entry))
      rescue StandardError
        false
      end

      def document_count(entry)
        return 0 unless index_exists?(entry)

        client.count(index: index_name_for(entry)).fetch('count', 0)
      rescue StandardError
        0
      end

      def index_stats(entry)
        return {} unless index_exists?(entry)

        index_stats = client.indices.stats(index: index_name_for(entry))
        indices_hash = index_stats.fetch('indices', {})
        indices_hash[index_name_for(entry)] || {}
      rescue StandardError
        {}
      end

      def index_record(record)
        return log_skipped_write(record, :index) unless available?

        record.__elasticsearch__.index_document
      end

      def delete_record(record)
        return log_skipped_write(record, :delete) unless available?

        record.__elasticsearch__.delete_document
      end

      private

      def client
        ::Elasticsearch::Model.client
      end

      def build_response(query)
        ::Elasticsearch::Model.search(ElasticsearchQuery.build(query), Registry.models.select { |model| BetterTogether::Elasticsearch.integrated_model?(model) })
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

      def log_skipped_write(record, action)
        Rails.logger.warn(
          "[BetterTogether::Search::ElasticsearchBackend] Skipping #{action} for " \
          "#{record.class.name}##{record.id || 'new'} because Elasticsearch is unavailable"
        )
        false
      end

      def missing_index_error?(error)
        error.class.name.end_with?('NotFound') || error.message.include?('index_not_found_exception')
      end

      def index_name_for(entry)
        return unless BetterTogether::Elasticsearch.integrated_model?(entry.model_class)

        entry.model_class.__elasticsearch__.index_name
      end
    end
  end
end
