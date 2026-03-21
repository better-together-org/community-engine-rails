# frozen_string_literal: true

module BetterTogether
  # Search backend selection and registry facade.
  module Search
    module_function

    def backend
      @backend ||= case backend_key
                   when 'elasticsearch'
                     BetterTogether::Search::ElasticsearchBackend.new
                   else
                     BetterTogether::Search::ElasticsearchBackend.new
                   end
    end

    def backend_key
      ENV.fetch('SEARCH_BACKEND', 'elasticsearch')
    end

    def reset_backend!
      @backend = nil
    end
  end
end
