# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe BetterTogether::Search::ElasticsearchBackend do
  subject(:backend) { described_class.new }

  let(:document_proxy_class) { stub_const('SpecElasticsearchModelProxy', Class.new) }
  let(:response_class) { stub_const('SpecElasticsearchResponse', Class.new) }
  let(:record_proxy_class) { stub_const('SpecElasticsearchRecordProxy', Class.new) }
  let(:model_class) { class_double(BetterTogether::Page) }
  let(:document_proxy) do
    instance_double(
      document_proxy_class,
      index_name: 'better_together-pages',
      create_index!: true,
      delete_index!: true,
      refresh_index!: true,
      import: true
    )
  end
  let(:entry) { instance_double(BetterTogether::Search::Registry::Entry, model_class:) }
  let(:client) { instance_double(Elasticsearch::Client) }
  let(:indices) { instance_double(Elasticsearch::API::Indices::IndicesClient) }

  before do
    allow(BetterTogether::ElasticsearchClientOptions).to receive(:enabled?).and_return(true)
    allow(BetterTogether::Elasticsearch).to receive(:integrated_model?).and_return(false)
    allow(BetterTogether::Elasticsearch).to receive(:integrated_model?).with(model_class).and_return(true)
    allow(model_class).to receive(:__elasticsearch__).and_return(document_proxy)
    allow(Elasticsearch::Model).to receive(:client).and_return(client)
    allow(client).to receive_messages(indices:, ping: true)
  end

  describe '#configured?' do
    it 'returns true when elasticsearch is enabled and the client is present' do
      expect(backend.configured?).to be(true)
    end

    it 'returns false when elasticsearch is not enabled for the current bundle' do
      allow(BetterTogether::ElasticsearchClientOptions).to receive(:enabled?).and_return(false)

      expect(backend.configured?).to be(false)
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

  describe '#search' do
    let(:page) { instance_double(BetterTogether::Page) }
    let(:response) do
      instance_double(
        response_class,
        records: [page],
        response: {
          'suggest' => {
            'suggestions' => [
              { 'options' => [{ 'text' => 'page' }] }
            ]
          }
        }
      )
    end

    before do
      allow(BetterTogether::Search::Registry).to receive(:models).and_return([model_class, BetterTogether::Post])
      allow(BetterTogether::Elasticsearch).to receive(:integrated_model?).with(BetterTogether::Post).and_return(false)
      allow(Elasticsearch::Model).to receive(:search).and_return(response)
    end

    it 'queries only elasticsearch-integrated registry models' do
      result = backend.search('page')

      expect(Elasticsearch::Model).to have_received(:search).with(
        BetterTogether::Search::ElasticsearchQuery.build('page'),
        [model_class]
      )
      expect(result.records).to eq([page])
      expect(result.suggestions).to eq(['page'])
      expect(result.status).to eq(:ok)
      expect(result.backend).to eq(:elasticsearch)
    end

    it 'returns a disabled result when elasticsearch is not configured' do
      allow(BetterTogether::ElasticsearchClientOptions).to receive(:enabled?).and_return(false)

      result = backend.search('page')

      expect(result.status).to eq(:disabled)
      expect(result.records).to eq([])
      expect(result.suggestions).to eq([])
    end

    it 'returns an unreachable result when the search request raises' do
      allow(Elasticsearch::Model).to receive(:search).and_raise(Faraday::ConnectionFailed.new('boom'))

      result = backend.search('page')

      expect(result.status).to eq(:unreachable)
      expect(result.error).to include('Faraday::ConnectionFailed')
    end
  end

  describe '#ensure_index' do
    it 'creates a missing index' do
      allow(indices).to receive(:exists).with(index: 'better_together-pages').and_return(false, true)

      expect(document_proxy).to receive(:create_index!)

      expect(backend.ensure_index(entry)).to be(true)
    end

    it 'does not recreate an existing index' do
      allow(indices).to receive(:exists).with(index: 'better_together-pages').and_return(true)

      expect(document_proxy).not_to receive(:create_index!)

      expect(backend.ensure_index(entry)).to be(true)
    end
  end

  describe '#import_model' do
    it 'ensures the index exists before importing records' do
      allow(indices).to receive(:exists).with(index: 'better_together-pages').and_return(false, true)

      expect(document_proxy).to receive(:create_index!).ordered
      expect(document_proxy).to receive(:import).with({ force: true }).ordered

      backend.import_model(entry, force: true)
    end
  end

  describe '#delete_index' do
    it 'ignores missing-index deletes caused by parallel index churn' do
      allow(indices).to receive(:exists).with(index: 'better_together-pages').and_return(true)
      allow(document_proxy).to receive(:delete_index!)
        .and_raise(StandardError.new('[404] {"error":{"type":"index_not_found_exception"},"status":404}'))

      expect { backend.delete_index(entry) }.not_to raise_error
    end
  end

  describe '#index_record' do
    let(:record_proxy) { instance_double(record_proxy_class, index_document: true, delete_document: true) }
    let(:record) { instance_double(BetterTogether::Page, id: 'record-id', __elasticsearch__: record_proxy) }

    it 'delegates indexing to the elasticsearch document proxy when available' do
      expect(record_proxy).to receive(:index_document)

      backend.index_record(record)
    end

    it 'logs and returns false when elasticsearch is unavailable' do
      allow(client).to receive(:ping).and_raise(Faraday::ConnectionFailed.new('down'))
      allow(Rails.logger).to receive(:warn)

      expect(backend.index_record(record)).to be(false)
      expect(Rails.logger).to have_received(:warn).with(include('Skipping index'))
    end
  end
end
