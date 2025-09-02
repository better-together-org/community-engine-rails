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

    it 'removes all geography records' do # rubocop:todo RSpec/MultipleExpectations
      expect(BetterTogether::Geography::Continent.count).to eq(1)
      described_class.clear_existing
      expect(BetterTogether::Geography::Continent.count).to eq(0)
    end
  end

  describe '.seed_continents' do
    before { described_class.clear_existing }

    # rubocop:todo RSpec/MultipleExpectations
    it 'creates continents from the predefined list' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      continents_count = described_class.send(:continents).size
      expect do
        described_class.seed_continents
      end.to change(BetterTogether::Geography::Continent, :count).by(continents_count)

      first = described_class.send(:continents).first
      record = BetterTogether::Geography::Continent.find_by(identifier: first[:name].parameterize)
      expect(record.name).to eq(first[:name])
      expect(record.description).to eq(first[:description])
    end
  end
end
