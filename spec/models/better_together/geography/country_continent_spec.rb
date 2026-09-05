# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::CountryContinent do
  subject(:country_continent) do
    described_class.new(country: country, continent: continent)
  end

  let(:country) { create(:geography_country) }
  let(:continent) { create(:geography_continent) }

  describe 'validations' do
    it 'is valid with country and continent' do
      expect(country_continent).to be_valid
    end

    it 'requires country_id' do
      country_continent.country = nil
      expect(country_continent).not_to be_valid
    end

    it 'requires continent_id' do
      country_continent.continent = nil
      expect(country_continent).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a country' do
      cc = create(:geography_country_continent)
      expect(cc.country).to be_a(BetterTogether::Geography::Country)
    end

    it 'belongs to a continent' do
      cc = create(:geography_country_continent)
      expect(cc.continent).to be_a(BetterTogether::Geography::Continent)
    end
  end
end
