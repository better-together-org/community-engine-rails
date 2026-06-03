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

    expect(result.status).to eq(:ok), result.error
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

    expect(result.status).to eq(:ok), result.error
    expect(result.records).to eq([record])
  end

  it 'matches page markdown block content through the database-backed fallback' do
    token = 'alphamarkdownorbit1001'
    page = create(
      :better_together_page,
      title: 'Markdown Search Page',
      slug: 'markdown-search-page',
      privacy: 'public',
      page_blocks_attributes: [
        {
          block_attributes: {
            type: 'BetterTogether::Content::Markdown',
            markdown_source: "This page only mentions #{token} in markdown."
          }
        }
      ]
    )

    allow(BetterTogether::Search::Registry).to receive(:entries).and_return([BetterTogether::Page.search_registry_entry])

    result = backend.search(token)

    expect(result.status).to eq(:ok), result.error
    expect(result.records).to contain_exactly(page)
  end

  it 'matches community translated text content through pg_search associations' do
    token = 'communitysignalharbor1002'
    community = create(
      :better_together_community,
      name: 'Community Search Group',
      description: "This community description includes #{token}.",
      privacy: 'public'
    )

    allow(BetterTogether::Search::Registry).to receive(:entries).and_return([BetterTogether::Community.search_registry_entry])

    result = backend.search(token)

    expect(result.status).to eq(:ok), result.error
    expect(result.records).to contain_exactly(community)
  end
end
