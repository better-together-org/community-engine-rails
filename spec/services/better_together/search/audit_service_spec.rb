# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Search::AuditService do
  subject(:audit_result) { described_class.new(backend:).call }

  let(:backend) do
      instance_double(
        BetterTogether::Search::BaseBackend,
        backend_key: :elasticsearch,
        configured?: true,
        available?: true,
      audit_report_labels: {
        collection: 'Indices',
        identifier: 'Index',
        documents: 'Indexed Documents',
        size: 'Store Size'
      },
      audit_capabilities: {
        store_size: true,
        existence_checks: true
      }
    )
  end
  let(:page_entry) { instance_double(BetterTogether::Search::Registry::Entry, model_name: 'BetterTogether::Page', db_count: 3) }
  let(:post_entry) { instance_double(BetterTogether::Search::Registry::Entry, model_name: 'BetterTogether::Post', db_count: 5) }

  before do
    allow(backend).to receive_messages(
      index_exists?: true,
      audit_store_exists?: true,
      audit_search_mode: 'elasticsearch'
    )
    allow(backend).to receive(:audit_store_identifier).and_return('better_together-pages', 'better_together-posts')
    allow(backend).to receive(:document_count).and_return(3, 4)
    allow(backend).to receive(:index_stats).and_return(
      {
        'total' => { 'store' => { 'size_in_bytes' => 1024 }, 'docs' => { 'count' => 3 } },
        'primaries' => { 'docs' => { 'count' => 3 } }
      },
      {
        'total' => { 'store' => { 'size_in_bytes' => 2048 }, 'docs' => { 'count' => 4 } },
        'primaries' => { 'docs' => { 'count' => 4 } }
      }
    )

    allow(BetterTogether::Search::Registry).to receive_messages(
      entries: [page_entry, post_entry],
      unmanaged_searchable_models: []
    )
  end

  it 'reports per-model drift and totals' do
    expect(audit_result.status).to eq(:ok)
    expect(audit_result.entries.map(&:model_name)).to eq(['BetterTogether::Page', 'BetterTogether::Post'])
    expect(audit_result.entries.map(&:store_identifier)).to eq(%w[better_together-pages better_together-posts])
    expect(audit_result.entries.map(&:drift_count)).to eq([0, 1])
    expect(audit_result.total_db_count).to eq(8)
    expect(audit_result.total_document_count).to eq(7)
    expect(audit_result.total_drift_count).to eq(1)
  end

  it 'serializes to JSON-friendly output' do
    json = audit_result.as_json

    expect(json[:backend]).to eq(:elasticsearch)
    expect(json[:report_labels]).to eq(
      collection: 'Indices',
      identifier: 'Index',
      documents: 'Indexed Documents',
      size: 'Store Size'
    )
    expect(json[:capabilities]).to eq(store_size: true, existence_checks: true)
    expect(json[:entries].size).to eq(2)
    expect(json[:healthy]).to be(false)
  end

  context 'when the backend is disabled' do
    before do
      allow(backend).to receive_messages(
        configured?: false,
        available?: false,
        audit_capabilities: { store_size: true, existence_checks: true }
      )
    end

    it 'reports a disabled status' do
      expect(audit_result.status).to eq(:disabled)
      expect(audit_result.entries).to all(have_attributes(status: :disabled))
    end
  end

  context 'when using pg_search' do
    let(:backend) do
      instance_double(
        BetterTogether::Search::BaseBackend,
        backend_key: :pg_search,
        configured?: true,
        available?: true,
        audit_report_labels: {
          collection: 'Scopes',
          identifier: 'Scope',
          documents: 'Searchable Records',
          size: 'Store Size'
        },
        audit_capabilities: {
          store_size: false,
          existence_checks: false
        }
      )
    end

    let(:page_entry) do
      instance_double(
        BetterTogether::Search::Registry::Entry,
        model_name: 'BetterTogether::Page',
        db_count: 3
      )
    end

    before do
      allow(backend).to receive_messages(
        audit_store_exists?: true,
        audit_store_identifier: 'pg_search_query',
        audit_search_mode: 'pg_search',
        document_count: 3,
        index_stats: {}
      )
      allow(BetterTogether::Search::Registry).to receive_messages(
        entries: [page_entry],
        unmanaged_searchable_models: []
      )
    end

    it 'reports backend-aware labels without index-specific capabilities' do
      expect(audit_result.backend).to eq(:pg_search)
      expect(audit_result.collection_label).to eq('Scopes')
      expect(audit_result.identifier_label).to eq('Scope')
      expect(audit_result.documents_label).to eq('Searchable Records')
      expect(audit_result).not_to be_supports_store_size
      expect(audit_result).not_to be_supports_existence_checks
      expect(audit_result.entries.first.store_identifier).to eq('pg_search_query')
      expect(audit_result.entries.first.status).to eq(:healthy)
    end
  end
end
