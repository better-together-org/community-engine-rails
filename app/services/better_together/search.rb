# frozen_string_literal: true

module BetterTogether
  # Search backend selection and registry facade.
  module Search
    DEFAULT_BACKEND_FACTORIES = {
      elasticsearch: -> { BetterTogether::Search::ElasticsearchBackend.new },
      database: -> { BetterTogether::Search::DatabaseBackend.new },
      pg_search: -> { BetterTogether::Search::PgSearchBackend.new }
    }.freeze

    module_function

    def backend
      @backend ||= resolve_backend
    end

    def backend_key
      ENV.fetch('SEARCH_BACKEND', 'elasticsearch').to_sym
    end

    def reset_backend!
      @backend = nil
    end

    def backend_class
      backend.class
    end

    def register_default_backends!
      DEFAULT_BACKEND_FACTORIES.each do |name, factory|
        next if BetterTogether.adapter_for(:search, name).present?

        BetterTogether.register_adapter(:search, name, factory)
      end
    end

    def backend_entry(name = backend_key)
      register_default_backends!
      BetterTogether.adapter_for(:search, name) || BetterTogether.adapter_for(:search, :elasticsearch)
    end

    def backend_factory(name = backend_key)
      backend_entry(name)&.fetch(:adapter)
    end

    def resolve_backend
      backend_candidate = backend_factory.call
      return backend_candidate if backend_candidate.is_a?(BaseBackend)

      raise TypeError, "Search adapter #{backend_key.inspect} must return a BetterTogether::Search::BaseBackend"
    end
  end
end
