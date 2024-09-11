# frozen_string_literal: true

# config/initializers/elasticsearch.rb
Elasticsearch::Model.client = Elasticsearch::Client.new(
  port: ENV.fetch('ES_PORT', 9200),
  host: ENV.fetch('ES_HOST', 'http://elasticsearch'),
  url: ENV.fetch('ELASTICSEARCH_URL', 'http://elasticsearch:9201')
)
