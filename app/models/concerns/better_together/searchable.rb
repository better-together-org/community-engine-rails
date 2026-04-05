# frozen_string_literal: true

# app/models/concerns/searchable.rb

module BetterTogether
  # Shared model-side search contract for all backend implementations.
  module Searchable
    extend ActiveSupport::Concern

    included do
      include Elasticsearch::Model
      include PgSearch::Model

      include Elasticsearch::Model::Callbacks unless Rails.env.test?

      after_commit :enqueue_index_document, if: :persisted?, unless: -> { Rails.env.test? }
      after_commit :enqueue_delete_document, on: [:destroy], unless: -> { Rails.env.test? }

      class_attribute :search_global_search_enabled, instance_writer: false, default: true
      class_attribute :search_scope_name, instance_writer: false, default: nil
      class_attribute :search_pg_search_options, instance_writer: false, default: nil
    end

    # Class-level helpers for searchable models.
    module ClassMethods
      def searchable(scope_name: :pg_search_query, global_search: true, pg_search: nil)
        self.search_global_search_enabled = global_search
        self.search_scope_name = pg_search.present? ? scope_name : nil
        self.search_pg_search_options = pg_search&.deep_dup

        pg_search_scope(scope_name, **pg_search) if pg_search.present?
      end

      def elasticsearch_runtime_enabled?
        !Rails.env.test? || ENV['ENABLE_ELASTICSEARCH_TESTS'] == 'true'
      end

      def create_elastic_index!
        __elasticsearch__.create_index! if elasticsearch_runtime_enabled?
      end

      def delete_elastic_index!
        __elasticsearch__.delete_index! if elasticsearch_runtime_enabled?
      end

      def refresh_elastic_index!
        __elasticsearch__.refresh_index! if elasticsearch_runtime_enabled?
      end

      # Need to create another way to access elasticsearch import.
      # class.import is used by activerecord-import.
      def elastic_import(args = {})
        __elasticsearch__.import(args) if elasticsearch_runtime_enabled?
      end

      def indexed_models
        BetterTogether::Search::Registry.models
      end

      def unmanaged_models
        included_in_models - indexed_models
      end

      def global_searchable?
        search_global_search_enabled
      end

      def search_relation
        all
      end

      def pg_search_enabled?
        search_pg_search_options.present? && search_scope_name.present?
      end

      def search_backend_query(query)
        return search_relation unless pg_search_enabled?

        public_send(search_scope_name, query)
      end

      def search_registry_entry
        BetterTogether::Search::Registry::Entry.new(
          model_name: name,
          global_search: global_searchable?
        )
      end

      def default_elasticsearch_index # rubocop:todo Metrics/MethodLength
        {
          number_of_shards: 1,
          analysis: {
            tokenizer: {
              edge_ngram_tokenizer: {
                type: 'edge_ngram',
                min_gram: 2,
                max_gram: 20,
                token_chars: %w[letter digit]
              }
            },
            analyzer: {
              custom_analyzer: {
                tokenizer: 'edge_ngram_tokenizer',
                filter: %w[lowercase asciifolding]
              }
            }
          }
        }
      end
    end

    def self.included_in_models
      Rails.application.eager_load! unless Rails.env.production? # Ensure all models are loaded
      ActiveRecord::Base.descendants.select { |model| model.include?(BetterTogether::Searchable) }
    end

    private

    def enqueue_index_document
      BetterTogether::ElasticsearchIndexJob.perform_later(self, :index)
    end

    def enqueue_delete_document
      BetterTogether::ElasticsearchIndexJob.perform_later(self, :delete)
    end

    def search_text_value(value)
      if value.respond_to?(:body) && value.body.respond_to?(:to_plain_text)
        value.body.to_plain_text
      elsif value.respond_to?(:to_plain_text)
        value.to_plain_text
      else
        value.to_s
      end
    end
  end
end
