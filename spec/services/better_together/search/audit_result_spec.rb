# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Search::AuditResult, type: :service do
  def build_entry(overrides = {})
    BetterTogether::Search::AuditEntryResult.new(
      *BetterTogether::Search::AuditEntryResult.members.map { |k| overrides[k] }
    ).tap do |e|
      e[:db_count] = overrides.fetch(:db_count, 5)
      e[:document_count] = overrides.fetch(:document_count, 5)
      e[:drift_count] = overrides.fetch(:drift_count, 0)
      e[:status] = overrides.fetch(:status, :healthy)
    end
  end

  subject(:result) do
    described_class.new(
      :pg_search,
      true,
      true,
      :ok,
      generated_at,
      [entry_a, entry_b],
      [],
      { collection: 'Posts', identifier: 'Index', documents: 'Records', size: 'Size' },
      { store_size: true, existence_checks: true }
    )
  end

  let(:entry_a) { build_entry(db_count: 10, document_count: 10, drift_count: 0, status: :healthy) }
  let(:entry_b) { build_entry(db_count: 5, document_count: 4, drift_count: 1, status: :drifted) }
  let(:generated_at) { Time.current }

  describe '#entries' do
    it 'is an alias for entry_results' do
      expect(result.entries).to eq(result.entry_results)
    end
  end

  describe 'label helpers' do
    it 'returns collection_label from report_labels' do
      expect(result.collection_label).to eq('Posts')
    end

    it 'returns identifier_label from report_labels' do
      expect(result.identifier_label).to eq('Index')
    end

    it 'returns documents_label from report_labels' do
      expect(result.documents_label).to eq('Records')
    end

    it 'returns size_label from report_labels' do
      expect(result.size_label).to eq('Size')
    end

    it 'falls back to default collection_label when report_labels is nil' do
      result_no_labels = described_class.new(:database, true, true, :ok, generated_at, [], [], nil, nil)
      expect(result_no_labels.collection_label).to eq('Search Stores')
    end
  end

  describe 'capability helpers' do
    it 'supports_store_size? returns true when capability set' do
      expect(result.supports_store_size?).to be true
    end

    it 'supports_existence_checks? returns true when capability set' do
      expect(result.supports_existence_checks?).to be true
    end
  end

  describe 'aggregate counts' do
    it 'sums total_db_count across entries' do
      expect(result.total_db_count).to eq(15)
    end

    it 'sums total_document_count across entries' do
      expect(result.total_document_count).to eq(14)
    end

    it 'sums total_drift_count across entries' do
      expect(result.total_drift_count).to eq(1)
    end
  end

  describe '#healthy?' do
    it 'returns false when drift_count is non-zero' do
      expect(result.healthy?).to be false
    end

    it 'returns true when status is :ok, drift is zero, and all entries are :healthy' do
      healthy_result = described_class.new(:database, true, true, :ok, generated_at,
                                           [entry_a], [], nil, nil)
      expect(healthy_result.healthy?).to be true
    end
  end

  describe '#as_json' do
    it 'includes top-level summary fields and entries array' do
      json = result.as_json
      expect(json).to include(:backend, :configured, :available, :status, :total_db_count)
      expect(json[:entries]).to be_an(Array)
    end
  end
end
