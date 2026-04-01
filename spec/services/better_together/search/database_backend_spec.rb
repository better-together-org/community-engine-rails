# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Search::DatabaseBackend do
  subject(:backend) { described_class.new }

  let(:page_record) do
    instance_double(
      BetterTogether::Page,
      id: 10,
      class: BetterTogether::Page,
      as_indexed_json: {
        title: 'Borgberry seed packet',
        template_content: { en: 'Community archive and public launch notes' }
      }
    )
  end
  let(:post_record) do
    instance_double(
      BetterTogether::Post,
      id: 20,
      class: BetterTogether::Post,
      as_indexed_json: {
        title: 'Weekly digest',
        content_en: 'Unrelated community update'
      }
    )
  end
  let(:page_relation) { [page_record] }
  let(:post_relation) { [post_record] }
  let(:page_entry) { instance_double(BetterTogether::Search::Registry::Entry, relation: page_relation, db_count: 1) }
  let(:post_entry) { instance_double(BetterTogether::Search::Registry::Entry, relation: post_relation, db_count: 1) }

  before do
    allow(BetterTogether::Search::Registry).to receive(:entries).and_return([page_entry, post_entry])
  end

  describe '#search' do
    it 'returns matching records from the configured registry entries' do
      result = backend.search('borgberry archive')

      expect(result.status).to eq(:ok)
      expect(result.backend).to eq(:database)
      expect(result.records).to eq([page_record])
      expect(result.suggestions).to eq([])
    end

    it 'returns an idle result for a blank query' do
      result = backend.search(' ')

      expect(result.status).to eq(:idle)
      expect(result.records).to eq([])
    end
  end

  describe '#document_count' do
    it 'reflects the relation size from the registry entry' do
      expect(backend.document_count(page_entry)).to eq(1)
    end
  end

  describe '#index lifecycle methods' do
    it 'behaves as a no-op backend for indexing operations' do
      expect(backend.ensure_index(page_entry)).to be(true)
      expect(backend.import_model(page_entry, force: true)).to be(true)
      expect(backend.refresh_index(page_entry)).to be(true)
      expect(backend.index_record(page_record)).to be(true)
      expect(backend.delete_record(page_record)).to be(true)
    end
  end
end
