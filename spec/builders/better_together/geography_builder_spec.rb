# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::GeographyBuilder, type: :model do
  describe '.clear_existing' do
    before do
      # create a continent to ensure delete_all works
      BetterTogether::Geography::Continent.create!(
        identifier: 'foo', name: 'Foo', description: 'desc', slug: 'foo', protected: false
      )
    end

    it 'removes all geography records' do
      expect(BetterTogether::Geography::Continent.count).to eq(1)
      BetterTogether::GeographyBuilder.clear_existing
      expect(BetterTogether::Geography::Continent.count).to eq(0)
    end
  end

  describe '.seed_continents' do
    before { BetterTogether::GeographyBuilder.clear_existing }

    it 'creates continents from the predefined list' do
      continents_count = BetterTogether::GeographyBuilder.send(:continents).size
      expect do
        BetterTogether::GeographyBuilder.seed_continents
      end.to change(BetterTogether::Geography::Continent, :count).by(continents_count)

      first = BetterTogether::GeographyBuilder.send(:continents).first
      record = BetterTogether::Geography::Continent.find_by(identifier: first[:name].parameterize)
      expect(record.name).to eq(first[:name])
      expect(record.description).to eq(first[:description])
    end
  end
end
