# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Search::ElasticsearchBackend do
  subject(:backend) { described_class.new }

  let(:model_class) { class_double(BetterTogether::Page, create_elastic_index!: true, elastic_import: true) }
  let(:entry) { instance_double(BetterTogether::Search::Registry::Entry, model_class:, index_name: 'better_together-pages') }
  let(:client) { instance_double(Elasticsearch::Client) }
  let(:indices) { instance_double(Elasticsearch::API::Indices::IndicesClient) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ELASTICSEARCH_URL').and_return('http://example.test:9200')
    allow(ENV).to receive(:[]).with('ES_HOST').and_return(nil)
    allow(ENV).to receive(:[]).with('ES_PORT').and_return(nil)
    allow(Elasticsearch::Model).to receive(:client).and_return(client)
    allow(client).to receive_messages(indices:, ping: true)
  end

  describe '#configured?' do
    it 'treats the initializer-provided client as configured without env vars' do
      allow(ENV).to receive(:[]).with('ELASTICSEARCH_URL').and_return(nil)
      allow(ENV).to receive(:[]).with('ES_HOST').and_return(nil)
      allow(ENV).to receive(:[]).with('ES_PORT').and_return(nil)

      expect(backend.configured?).to be(true)
    end
  end

  describe '#available?' do
    it 'returns true when the client responds to ping' do
      expect(backend.available?).to be(true)
    end

    it 'returns false when the client is unreachable' do
      allow(client).to receive(:ping).and_raise(Faraday::ConnectionFailed.new('unreachable'))

      expect(backend.available?).to be(false)
    end
  end

  describe '#ensure_index' do
    it 'creates a missing index' do
      allow(indices).to receive(:exists).with(index: entry.index_name).and_return(false, true)

      expect(model_class).to receive(:create_elastic_index!)

      expect(backend.ensure_index(entry)).to be(true)
    end

    it 'does not recreate an existing index' do
      allow(indices).to receive(:exists).with(index: entry.index_name).and_return(true)

      expect(model_class).not_to receive(:create_elastic_index!)

      expect(backend.ensure_index(entry)).to be(true)
    end
  end

  describe '#import_model' do
    it 'ensures the index exists before importing records' do
      allow(indices).to receive(:exists).with(index: entry.index_name).and_return(false, true)

      expect(model_class).to receive(:create_elastic_index!).ordered
      expect(model_class).to receive(:elastic_import).with({ force: true }).ordered

      backend.import_model(entry, force: true)
    end
  end
end
