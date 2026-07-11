# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::CommunityCollectionMap do
  describe 'STI inheritance' do
    it 'is a subclass of CommunityMap' do
      expect(described_class.superclass).to eq(BetterTogether::Geography::CommunityMap)
    end

    it 'inherits mappable_class from CommunityMap' do
      expect(described_class.mappable_class).to eq(BetterTogether::Community)
    end
  end

  describe '.records' do
    it 'returns an ActiveRecord::Relation' do
      expect(described_class.records).to be_a(ActiveRecord::Relation)
    end
  end

  describe '#records' do
    subject(:instance) do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      described_class.new(
        zoom: 10,
        center: factory.point(-57.9474, 48.9517),
        privacy: 'public',
        protected: false,
        title: 'Collection Map',
        identifier: "col-map-#{SecureRandom.hex(4)}"
      )
    end

    it 'delegates to the class method' do
      expect(instance.records).to eq(described_class.records)
    end
  end

  describe '#spaces' do
    it 'returns an array' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      instance = described_class.new(
        zoom: 10,
        center: factory.point(-57.9474, 48.9517),
        privacy: 'public',
        protected: false
      )
      expect(instance.spaces).to be_an(Array)
    end
  end

  describe '#leaflet_points' do
    it 'returns an array' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      instance = described_class.new(
        zoom: 10,
        center: factory.point(-57.9474, 48.9517),
        privacy: 'public',
        protected: false
      )
      expect(instance.leaflet_points).to be_an(Array)
    end
  end
end
