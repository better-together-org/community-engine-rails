# frozen_string_literal: true

module BetterTogether
  module Elasticsearch
    class Engine < ::Rails::Engine
      engine_name 'better_together_elasticsearch'

      initializer 'better_together_elasticsearch.search_adapter' do
        next if BetterTogether.adapter_for(:search, :elasticsearch).present?

        BetterTogether.register_adapter(:search, :elasticsearch, -> { BetterTogether::Search::ElasticsearchBackend.new })
      end

      initializer 'better_together_elasticsearch.model_documents' do
        BetterTogether::Elasticsearch.register_default_documents!

        config.to_prepare do
          BetterTogether::Elasticsearch.apply_model_documents!
        end
      end

      initializer 'better_together_elasticsearch.client' do
        next unless BetterTogether::ElasticsearchClientOptions.enabled?

        ::Elasticsearch::Model.client = ::Elasticsearch::Client.new(
          **BetterTogether::ElasticsearchClientOptions.build
        )
      end
    end
  end
end
