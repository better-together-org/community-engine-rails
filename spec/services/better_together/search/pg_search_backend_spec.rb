# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Search::PgSearchBackend do
  subject(:backend) { described_class.new }

  it 'reports the pg_search backend key while reusing the database fallback behavior' do
    expect(backend.backend_key).to eq(:pg_search)
    expect(backend).to be_a(BetterTogether::Search::DatabaseBackend)
  end

  it 'uses pg_search_query scopes when available' do
    search_result_class = Struct.new(:id, :pg_search_rank)
    record = instance_double(search_result_class, id: 10, pg_search_rank: 0.42)
    relation = instance_double(ActiveRecord::Relation)
    entry = instance_double(
      BetterTogether::Search::Registry::Entry,
      pg_search_enabled?: true,
      search_relation: relation
    )

    allow(BetterTogether::Search::Registry).to receive(:entries).and_return([entry])
    allow(entry).to receive(:search_relation).with('borgberry').and_return(relation)
    allow(relation).to receive(:limit).with(50).and_return([record])

    result = backend.search('borgberry')

    expect(result.status).to eq(:ok)
    expect(result.backend).to eq(:pg_search)
    expect(result.records).to eq([record])
  end

  it 'falls back to database scoring when a model has no pg_search scope configured' do
    record = instance_double(BetterTogether::Checklist, id: 10, as_indexed_json: { title: 'Borgberry checklist archive' })
    entry = instance_double(
      BetterTogether::Search::Registry::Entry,
      pg_search_enabled?: false,
      relation: [record]
    )

    allow(BetterTogether::Search::Registry).to receive(:entries).and_return([entry])

    result = backend.search('borgberry archive')

    expect(result.status).to eq(:ok)
    expect(result.records).to eq([record])
  end
end
