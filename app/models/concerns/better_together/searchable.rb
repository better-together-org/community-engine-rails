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

      def self.create_elastic_index!
        __elasticsearch__.create_index! unless Rails.env.test?
      end

      def self.delete_elastic_index!
        __elasticsearch__.delete_index! unless Rails.env.test?
      end

      def self.refresh_elastic_index!
        __elasticsearch__.refresh_index! unless Rails.env.test?
      end

      # Need to create another way to access elasticsearch import.
      # class.import is using by activerecord-import, I think
      def self.elastic_import(args = {})
        __elasticsearch__.import(args) unless Rails.env.test?
      end
    end

    class_methods do
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
      ActiveRecord::Base.descendants.select { |model| model.included_modules.include?(BetterTogether::Searchable) }
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
