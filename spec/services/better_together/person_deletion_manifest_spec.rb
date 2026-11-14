# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonDeletionManifest, type: :service do
  describe '.entries' do
    it 'returns an array of entry hashes' do
      expect(described_class.entries).to be_an(Array)
      expect(described_class.entries).not_to be_empty
    end

    it 'each entry has at least key, kind, owner, and action keys' do
      expect(described_class.entries).to all(include('key', 'kind', 'owner', 'action'))
    end

    it 'caches across calls without re-reading the file' do
      first = described_class.entries
      second = described_class.entries
      expect(first).to equal(second)
    end

    it 'includes a self-destruction entry for user' do
      user_entry = described_class.entries.find { |e| e['key'] == 'user' }
      expect(user_entry).to be_present
      expect(user_entry['action']).to eq('destroy')
    end
  end

  describe '.reload!' do
    it 'clears the cache and returns fresh entries' do
      original = described_class.entries
      described_class.reload!
      reloaded = described_class.entries
      expect(reloaded).to eq(original)
    end
  end
end
