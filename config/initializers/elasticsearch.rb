# frozen_string_literal: true

require BetterTogether::Engine.root.join('app/services/better_together/elasticsearch_client_options')

Elasticsearch::Model.client = Elasticsearch::Client.new(
  **BetterTogether::ElasticsearchClientOptions.build
)
