# frozen_string_literal: true

module BetterTogether
  module Elasticsearch
    # Shared Elasticsearch document behavior for CE and host-app records.
    module Document
      extend ActiveSupport::Concern

      included do
        include ::Elasticsearch::Model

        after_commit :enqueue_elasticsearch_index_document, if: :enqueue_elasticsearch_index_document?,
                                                            unless: -> { Rails.env.test? }
        after_commit :enqueue_elasticsearch_delete_document, on: [:destroy],
                                                             if: :enqueue_elasticsearch_delete_document?,
                                                             unless: -> { Rails.env.test? }
      end

      class_methods do # rubocop:disable Metrics/BlockLength
        def elasticsearch_runtime_enabled?
          !Rails.env.test? || ENV['ENABLE_ELASTICSEARCH_TESTS'] == 'true'
        end

        def elasticsearch_indexing_enabled?
          elasticsearch_runtime_enabled? && ENV.fetch('SEARCH_BACKEND', 'pg_search').to_sym == :elasticsearch
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

        def elastic_import(args = {})
          __elasticsearch__.import(args) if elasticsearch_runtime_enabled?
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

      private

      def enqueue_elasticsearch_index_document?
        persisted? && self.class.elasticsearch_indexing_enabled?
      end

      def enqueue_elasticsearch_delete_document?
        self.class.elasticsearch_indexing_enabled?
      end

      def enqueue_elasticsearch_index_document
        BetterTogether::ElasticsearchIndexJob.perform_later(self, :index)
      end

      def enqueue_elasticsearch_delete_document
        BetterTogether::ElasticsearchIndexJob.perform_later(self, :delete)
      end

      alias enqueue_index_document enqueue_elasticsearch_index_document
      alias enqueue_delete_document enqueue_elasticsearch_delete_document

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
end
