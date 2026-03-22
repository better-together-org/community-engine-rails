# frozen_string_literal: true

module BetterTogether
  # Search backend selection and registry facade.
  module Search
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
      BetterTogether::Search::ElasticsearchBackend
    end
  end
end
