# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SeedCatalog::Registry do
  describe '.all' do
    it 'includes the Geography catalog' do
      expect(described_class.all).to include(BetterTogether::SeedCatalog::GeographyCatalog)
    end
  end

  describe '.find' do
    it 'finds a catalog by symbol key' do
      expect(described_class.find(:geography)).to eq(BetterTogether::SeedCatalog::GeographyCatalog)
    end

    it 'finds a catalog by string key (route params arrive as strings)' do
      expect(described_class.find('geography')).to eq(BetterTogether::SeedCatalog::GeographyCatalog)
    end

    it 'returns nil for an unregistered key' do
      expect(described_class.find('not_a_real_catalog')).to be_nil
    end
  end
end
