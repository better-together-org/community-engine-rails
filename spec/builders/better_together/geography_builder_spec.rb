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

    it 'also destroys the auto-created Community for each geography record (not just the row itself)' do
      # Continent/Country/State/Region/Settlement each auto-create a Community via
      # PrimaryCommunity#has_community (dependent: :destroy). clear_existing must use
      # destroy_all (not delete_all, which skips this callback) or re-seeding orphans
      # these Community rows and duplicates them on every run.
      continent = BetterTogether::Geography::Continent.find_by(identifier: 'foo')
      community_id = continent.community_id
      expect(community_id).to be_present

      described_class.clear_existing

      expect(BetterTogether::Community.exists?(community_id)).to be false
    end
  end

  describe '.seed_continents' do
    before { described_class.clear_existing }

    # rubocop:todo RSpec/MultipleExpectations
    it 'creates continents from the predefined list' do # rubocop:todo RSpec/MultipleExpectations
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
