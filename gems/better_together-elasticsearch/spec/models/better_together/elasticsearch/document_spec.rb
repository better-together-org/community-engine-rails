# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe BetterTogether::Elasticsearch::Document do
  around do |example|
    original_backend = ENV.fetch('SEARCH_BACKEND', nil)
    original_enable_tests = ENV.fetch('ENABLE_ELASTICSEARCH_TESTS', nil)
    example.run
    ENV['SEARCH_BACKEND'] = original_backend
    ENV['ENABLE_ELASTICSEARCH_TESTS'] = original_enable_tests
  end

  describe '.elasticsearch_runtime_enabled?' do
    it 'is disabled in test by default' do
      ENV.delete('ENABLE_ELASTICSEARCH_TESTS')

      expect(BetterTogether::Page.elasticsearch_runtime_enabled?).to be(false)
    end

    it 'can be enabled explicitly for elasticsearch integration runs' do
      ENV['ENABLE_ELASTICSEARCH_TESTS'] = 'true'

      expect(BetterTogether::Page.elasticsearch_runtime_enabled?).to be(true)
    end
  end

  describe '.elasticsearch_indexing_enabled?' do
    it 'requires both the elasticsearch backend and explicit test enablement' do
      ENV['SEARCH_BACKEND'] = 'elasticsearch'
      ENV['ENABLE_ELASTICSEARCH_TESTS'] = 'true'

      expect(BetterTogether::Page.elasticsearch_indexing_enabled?).to be(true)
    end

    it 'stays disabled when the backend is not elasticsearch' do
      ENV['SEARCH_BACKEND'] = 'pg_search'
      ENV['ENABLE_ELASTICSEARCH_TESTS'] = 'true'

      expect(BetterTogether::Page.elasticsearch_indexing_enabled?).to be(false)
    end
  end

  describe 'callback hook helpers' do
    let(:page) { build_stubbed(:better_together_page) }

    before do
      ENV['SEARCH_BACKEND'] = 'elasticsearch'
      ENV['ENABLE_ELASTICSEARCH_TESTS'] = 'true'
    end

    it 'enqueues the index job through the alias hook' do
      allow(BetterTogether::ElasticsearchIndexJob).to receive(:perform_later)

      page.send(:enqueue_index_document)

      expect(BetterTogether::ElasticsearchIndexJob).to have_received(:perform_later).with(page, :index)
    end

    it 'enqueues the delete job through the alias hook' do
      allow(BetterTogether::ElasticsearchIndexJob).to receive(:perform_later)

      page.send(:enqueue_delete_document)

      expect(BetterTogether::ElasticsearchIndexJob).to have_received(:perform_later).with(page, :delete)
    end
  end
end
