# frozen_string_literal: true

# config/initializers/elasticsearch.rb

# Prefer a single URL. If ELASTICSEARCH_URL is not set, build it from ES_HOST and ES_PORT.
url = ENV['ELASTICSEARCH_URL'] || begin
  host = ENV.fetch('ES_HOST', 'http://localhost')
  port = ENV.fetch('ES_PORT', 9200)
  "#{host}:#{port}"
end

Elasticsearch::Model.client = Elasticsearch::Client.new(
  url: url,
  retry_on_failure: true,
  reload_connections: true,
  transport_options: { request: { timeout: 5, open_timeout: 2 } }
)
