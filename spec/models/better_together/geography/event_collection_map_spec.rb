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

    # Regression: Floor/Room have no independent space of their own (delegated
    # to their building), unlike Address/Building/Settlement/Region - .records'
    # eager-load hash must account for both shapes or this raises
    # ActiveRecord::AssociationNotFoundError as soon as a Floor/Room-located
    # event is in the result set.
    it 'does not raise for a Floor-located event and still aggregates its building-delegated space' do
      building_event = create(:event, :with_building_location)
      building = building_event.location.location
      create(:geography_geospatial_space, geospatial: building,
                                          space: create(:geography_space, latitude: 1.0, longitude: 1.0))

      floor = building.floors.first
      floor_event = create(:event)
      create(:locatable_location, locatable: floor_event, location: floor,
                                  location_type: 'BetterTogether::Infrastructure::Floor', name: nil)

      expect { described_class.records.to_a }.not_to raise_error

      points = instance.leaflet_points
      floor_point = points.find { |p| p[:popup_html].include?(floor.name) }
      expect(floor_point).not_to be_nil
      expect(floor_point[:lat]).to eq(1.0)
    end

    it 'does not raise for a Room-located event' do
      building_event = create(:event, :with_building_location)
      building = building_event.location.location
      room = building.floors.first.rooms.first
      room_event = create(:event)
      create(:locatable_location, locatable: room_event, location: room,
                                  location_type: 'BetterTogether::Infrastructure::Room', name: nil)

      expect { described_class.records.to_a }.not_to raise_error
    end
  end
end
