# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SeedCatalog::GeographyCatalog do
  before { BetterTogether::GeographyBuilder.clear_existing }

  describe '.key/.label/.description' do
    it 'identifies itself as the geography catalog' do
      expect(described_class.key).to eq(:geography)
      expect(described_class.label).to be_present
      expect(described_class.description).to be_present
    end
  end

  describe '.categories' do
    it 'exposes all five geography hierarchy levels' do
      expect(described_class.categories.map { |c| c[:key] }).to contain_exactly(
        :continents, :countries, :provinces, :regions, :settlements
      )
    end
  end

  describe '.planted?' do
    it 'is false before a category is seeded' do
      expect(described_class.planted?(:continents)).to be(false)
    end

    it 'is true once at least one record of that category exists' do
      BetterTogether::GeographyBuilder.seed_continents

      expect(described_class.planted?(:continents)).to be(true)
    end

    it 'is false for an unknown category key rather than raising' do
      expect(described_class.planted?(:not_a_category)).to be(false)
    end
  end

  describe '.missing_prerequisites' do
    it 'is empty for a category with no prerequisites' do
      expect(described_class.missing_prerequisites(:continents)).to eq([])
    end

    it 'lists an unplanted prerequisite' do
      expect(described_class.missing_prerequisites(:provinces)).to eq([:countries])
    end

    it 'is empty once the prerequisite is planted' do
      described_class.plant(:countries)

      expect(described_class.missing_prerequisites(:provinces)).to eq([])
    end

    it 'is empty for an unknown category key rather than raising' do
      expect(described_class.missing_prerequisites(:not_a_category)).to eq([])
    end
  end

  describe '.plant' do
    it 'seeds only the requested category' do
      described_class.plant(:continents)

      expect(BetterTogether::Geography::Continent.count).to be_positive
      expect(BetterTogether::Geography::Country.count).to eq(0)
    end

    it 'returns false for an unknown category key without raising' do
      result = nil
      expect { result = described_class.plant(:not_a_category) }.not_to raise_error
      expect(result).to be(false)
    end

    it 'returns false and does not raise when planting provinces before countries exist' do
      result = nil
      expect { result = described_class.plant(:provinces) }.not_to raise_error

      expect(result).to be(false)
      expect(BetterTogether::Geography::State.count).to eq(0)
    end

    it 'returns false and does not raise when planting settlements before provinces exist' do
      result = nil
      expect { result = described_class.plant(:settlements) }.not_to raise_error

      expect(result).to be(false)
      expect(BetterTogether::Geography::Settlement.count).to eq(0)
    end

    it 'succeeds once the prerequisite is planted first' do
      described_class.plant(:countries)

      expect(described_class.plant(:provinces)).to be(true)
      expect(BetterTogether::Geography::State.count).to be_positive
    end

    it 'syncs the country<->continent join once both sides are planted, regardless of plant order' do
      described_class.plant(:continents)
      expect(BetterTogether::Geography::CountryContinent.count).to eq(0)

      described_class.plant(:countries)

      expect(BetterTogether::Geography::CountryContinent.count).to be_positive
    end
  end

  describe '.plant_all' do
    it 'seeds every category via GeographyBuilder.build_if_missing' do
      described_class.plant_all

      expect(BetterTogether::Geography::Continent.count).to be_positive
      expect(BetterTogether::Geography::Settlement.count).to be_positive
      expect(BetterTogether::Geography::CountryContinent.count).to be_positive
    end

    it 'is idempotent' do
      described_class.plant_all
      count_after_first = BetterTogether::Geography::Continent.count

      expect { described_class.plant_all }.not_to raise_error
      expect(BetterTogether::Geography::Continent.count).to eq(count_after_first)
    end
  end
end
