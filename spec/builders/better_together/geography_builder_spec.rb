# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::GeographyBuilder do
  describe '.seed_data' do
    it 'calls all seed methods' do
      expect(described_class).to receive(:seed_continents)
      expect(described_class).to receive(:seed_countries)
      expect(described_class).to receive(:seed_country_continents)
      expect(described_class).to receive(:seed_provinces)
      expect(described_class).to receive(:seed_regions)
      expect(described_class).to receive(:seed_settlements)
      expect(described_class).to receive(:seed_region_settlements)
      described_class.seed_data
    end
  end

  describe '.clear_existing' do
    it 'deletes all geography records' do
      expect(BetterTogether::Geography::RegionSettlement).to receive(:delete_all)
      expect(BetterTogether::Geography::Settlement).to receive(:delete_all)
      expect(BetterTogether::Geography::Region).to receive(:delete_all)
      expect(BetterTogether::Geography::CountryContinent).to receive(:delete_all)
      expect(BetterTogether::Geography::State).to receive(:delete_all)
      expect(BetterTogether::Geography::Country).to receive(:delete_all)
      expect(BetterTogether::Geography::Continent).to receive(:delete_all)
      described_class.clear_existing
    end
  end
end
