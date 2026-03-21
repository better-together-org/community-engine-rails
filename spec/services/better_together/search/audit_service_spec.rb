# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Search::AuditService do
  subject(:audit_result) { described_class.new(backend:).call }

  let(:backend) do
    instance_double(
      BetterTogether::Search::ElasticsearchBackend,
      backend_key: :elasticsearch,
      configured?: true,
      available?: true
    )
  end
  let(:page_entry) { instance_double(BetterTogether::Search::Registry::Entry, model_name: 'BetterTogether::Page', index_name: 'better_together-pages', db_count: 3) }
  let(:post_entry) { instance_double(BetterTogether::Search::Registry::Entry, model_name: 'BetterTogether::Post', index_name: 'better_together-posts', db_count: 5) }

  before do
    allow(backend).to receive(:index_exists?).and_return(true)
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

    allow(BetterTogether::Search::Registry).to receive(:entries).and_return([page_entry, post_entry])
    allow(BetterTogether::Search::Registry).to receive(:unmanaged_searchable_models).and_return([])
  end

  it 'reports per-model drift and totals' do
    expect(audit_result.status).to eq(:ok)
    expect(audit_result.entries.map(&:model_name)).to eq(['BetterTogether::Page', 'BetterTogether::Post'])
    expect(audit_result.entries.map(&:drift_count)).to eq([0, 1])
    expect(audit_result.total_db_count).to eq(8)
    expect(audit_result.total_document_count).to eq(7)
    expect(audit_result.total_drift_count).to eq(1)
  end

  it 'serializes to JSON-friendly output' do
    json = audit_result.as_json

    expect(json[:backend]).to eq(:elasticsearch)
    expect(json[:entries].size).to eq(2)
    expect(json[:healthy]).to be(false)
  end

  context 'when the backend is disabled' do
    before do
      allow(backend).to receive(:configured?).and_return(false)
      allow(backend).to receive(:available?).and_return(false)
    end

    it 'reports a disabled status' do
      expect(audit_result.status).to eq(:disabled)
      expect(audit_result.entries).to all(have_attributes(status: :disabled))
    end
  end
end
