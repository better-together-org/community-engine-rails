# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Search do
  around do |example|
    original_backend = ENV.fetch('SEARCH_BACKEND', nil)
    original_registry = BetterTogether.adapter_registry
    BetterTogether.adapter_registry = BetterTogether::AdapterRegistry.new
    described_class.reset_backend!
    example.run
    ENV['SEARCH_BACKEND'] = original_backend
    BetterTogether.adapter_registry = original_registry
    described_class.reset_backend!
  end

  describe '.backend_class' do
    it 'uses Elasticsearch by default' do
      ENV.delete('SEARCH_BACKEND')

      expect(described_class.backend_class).to eq(BetterTogether::Search::ElasticsearchBackend)
    end

    it 'uses the database backend when configured explicitly' do
      ENV['SEARCH_BACKEND'] = 'database'

      expect(described_class.backend_class).to eq(BetterTogether::Search::DatabaseBackend)
    end

    it 'maps pg_search requests to the database backend until a dedicated implementation exists' do
      ENV['SEARCH_BACKEND'] = 'pg_search'

      expect(described_class.backend_class).to eq(BetterTogether::Search::PgSearchBackend)
    end

    it 'resolves registered search adapters through the shared adapter registry' do
      custom_backend_class = Class.new(BetterTogether::Search::BaseBackend)
      backend_instance = custom_backend_class.new

      ENV['SEARCH_BACKEND'] = 'custom'
      BetterTogether.register_adapter(:search, :custom, -> { backend_instance })

      expect(described_class.backend).to eq(backend_instance)
      expect(described_class.backend_class).to eq(custom_backend_class)
    end
  end
end
