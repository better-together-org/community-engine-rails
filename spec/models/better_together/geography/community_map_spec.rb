# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::CommunityMap do
  subject(:map) do
    factory = RGeo::Geographic.spherical_factory(srid: 4326)
    described_class.new(
      zoom: 10,
      center: factory.point(-57.9474, 48.9517),
      privacy: 'public',
      protected: false
    )
  end

  describe 'STI inheritance' do
    it 'is a subclass of Map' do
      expect(described_class.superclass).to eq(BetterTogether::Geography::Map)
    end

    it 'stores the correct STI type string' do
      expect(described_class.sti_name).to eq('BetterTogether::Geography::CommunityMap')
    end
  end

  describe '.mappable_class' do
    it 'returns BetterTogether::Community' do
      expect(described_class.mappable_class).to eq(BetterTogether::Community)
    end
  end

  describe 'persistence' do
    it 'can be saved with required attributes' do
      map.title = 'Community Map'
      map.identifier = "community-map-#{SecureRandom.hex(4)}"
      map.creator = create(:better_together_person)
      expect { map.save! }.not_to raise_error
    end
  end
end
