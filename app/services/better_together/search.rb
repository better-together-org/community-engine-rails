# frozen_string_literal: true

module BetterTogether
  # Search backend selection and registry facade.
  module Search
    BACKEND_REGISTRY = {
      'elasticsearch' => 'BetterTogether::Search::ElasticsearchBackend',
      'database' => 'BetterTogether::Search::DatabaseBackend',
      'pg_search' => 'BetterTogether::Search::PgSearchBackend'
    }.freeze

    module_function

    def backend
      @backend ||= backend_class.new
    end

    def backend_key
      ENV.fetch('SEARCH_BACKEND', 'elasticsearch')
    end

    def reset_backend!
      @backend = nil
    end

    def backend_class
      BACKEND_REGISTRY.fetch(backend_key, BACKEND_REGISTRY.fetch('elasticsearch')).constantize
    end
  end
end
