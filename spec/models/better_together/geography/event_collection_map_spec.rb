# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::EventCollectionMap do
  describe 'STI inheritance' do
    it 'is a subclass of LocatableMap' do
      expect(described_class.superclass).to eq(BetterTogether::Geography::LocatableMap)
    end

    it 'sets mappable_class to Event' do
      expect(described_class.mappable_class).to eq(BetterTogether::Event)
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
        title: 'Events Map',
        identifier: "events-map-#{SecureRandom.hex(4)}"
      )
    end

    it 'delegates to the class method' do
      expect(instance.records).to eq(described_class.records)
    end
  end

  describe '#leaflet_points and #spaces' do
    subject(:instance) do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      described_class.new(
        zoom: 10,
        center: factory.point(-57.9474, 48.9517),
        privacy: 'public',
        protected: false
      )
    end

    it 'returns empty arrays when no event has a location' do
      create(:event)

      expect(instance.leaflet_points).to eq([])
      expect(instance.spaces).to eq([])
    end

    it 'aggregates leaflet points across events with geocoded locations' do
      event = create(:event, :with_address_location)
      create(:geography_geospatial_space, geospatial: event.location.location, space: create(:geography_space))

      points = instance.leaflet_points

      expect(points.size).to eq(1)
      expect(instance.spaces.size).to eq(1)
    end
  end
end
