# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Search::AuditEntryResult, type: :service do
  def build_entry(overrides = {})
    defaults = {
      model_name: 'BetterTogether::Post',
      index_name: 'better_together_posts',
      db_count: 10,
      document_count: 10,
      drift_count: 0,
      status: :healthy,
      store_size_bytes: 1_024
    }
    described_class.new(*described_class.members.map { |k| overrides.fetch(k, defaults[k]) })
  end

  describe '#store_identifier' do
    it 'returns the explicit store_identifier when set' do
      entry = build_entry(store_identifier: 'custom-store')
      expect(entry.store_identifier).to eq('custom-store')
    end

    it 'falls back to index_name when store_identifier is nil' do
      entry = build_entry(store_identifier: nil)
      expect(entry.store_identifier).to eq('better_together_posts')
    end
  end

  describe '#store_exists' do
    it 'returns the explicit store_exists value when set' do
      entry = build_entry(store_exists: false)
      expect(entry.store_exists).to be false
    end

    it 'falls back to index_exists when store_exists is nil' do
      entry = build_entry(store_exists: nil, index_exists: true)
      expect(entry.store_exists).to be true
    end
  end

  describe '#index_exists' do
    it 'returns the explicit index_exists value when set' do
      entry = build_entry(index_exists: true)
      expect(entry.index_exists).to be true
    end

    it 'falls back to store_exists when index_exists is nil' do
      entry = build_entry(store_exists: true, index_exists: nil)
      expect(entry.index_exists).to be true
    end
  end

  describe '#store_size_human' do
    it 'returns a human-readable size string' do
      entry = build_entry(store_size_bytes: 2_048)
      expect(entry.store_size_human).to be_a(String)
      expect(entry.store_size_human).to include('KB').or include('Bytes').or include('MB')
    end

    it 'returns 0 Bytes when store_size_bytes is zero' do
      entry = build_entry(store_size_bytes: 0)
      expect(entry.store_size_human).to eq('0 Bytes')
    end
  end

  describe '#as_json' do
    it 'includes model_name, status, counts, and size fields' do
      entry = build_entry
      json = entry.as_json
      expect(json).to include(:model_name, :status, :db_count, :document_count, :drift_count, :store_size_bytes)
    end

    it 'includes store_size_human' do
      entry = build_entry
      expect(entry.as_json).to have_key(:store_size_human)
    end
  end
end
