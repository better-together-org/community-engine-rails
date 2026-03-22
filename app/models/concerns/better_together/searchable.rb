# frozen_string_literal: true

# app/models/concerns/searchable.rb

module BetterTogether
  # Enables ElasticSearch
  module Searchable
    extend ActiveSupport::Concern

    included do
      include Elasticsearch::Model

      include Elasticsearch::Model::Callbacks unless Rails.env.test?

      after_commit :enqueue_index_document, if: :persisted?, unless: -> { Rails.env.test? }
      after_commit :enqueue_delete_document, on: [:destroy], unless: -> { Rails.env.test? }
    end

    # Class-level helpers for searchable models.
    module ClassMethods
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
      Rails.application.eager_load! unless Rails.env.production?
      ActiveRecord::Base.descendants.select { |model| model.include?(BetterTogether::Searchable) }
    end

    private

    def enqueue_index_document
      BetterTogether::ElasticsearchIndexJob.perform_later(self, :index)
    end

    def enqueue_delete_document
      BetterTogether::ElasticsearchIndexJob.perform_later(self, :delete)
    end
  end
end
