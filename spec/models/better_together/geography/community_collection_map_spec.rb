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

  describe 'popup markup' do
    let(:person) { create(:better_together_person) }
    let(:hostile_name) { '<img src=x onerror=alert(1)> Hall' }
    let(:community) { create(:better_together_community, name: hostile_name, privacy: 'public') }
    let(:building) do
      create(:better_together_infrastructure_building, creator: person, name: 'Hall', privacy: 'public',
                                                       address: build(:better_together_address, line1: '<b>1 Main</b>',
                                                                                                city_name: 'Corner Brook',
                                                                                                country_name: 'Canada',
                                                                                                privacy: 'public',
                                                                                                primary_flag: true))
    end

    before do
      BetterTogether::Infrastructure::BuildingConnection.create!(building:, connection: community, position: 1,
                                                                 primary_flag: true)
      building.geospatial_space.space.assign_attributes(latitude: 48.95, longitude: -57.95)
      building.geospatial_space.save!
    end

    it 'escapes user supplied names and addresses in preloaded points', :aggregate_failures do
      map = described_class.new
      map.loaded_collection = described_class.records.to_a
      popup = map.leaflet_points.first[:popup_html]

      expect(popup).to include('&lt;img src=x onerror=alert(1)&gt; Hall')
      expect(popup).to include('&lt;b&gt;1 Main&lt;/b&gt;')
      expect(popup).not_to include('<img')
      expect(popup).not_to include('<b>1 Main')
    end

    it 'escapes them in the points the community builds itself', :aggregate_failures do
      popup = community.reload.leaflet_points.first[:popup_html]

      expect(popup).to include('&lt;img src=x onerror=alert(1)&gt; Hall')
      expect(popup).not_to include('<img')
    end
  end

  describe 'visible_scope' do
    it 'limits the collection to the communities in the scope', :aggregate_failures do
      shown = create(:better_together_community, privacy: 'public')
      hidden = create(:better_together_community, privacy: 'public')
      [shown, hidden].each do |community|
        address = build(:better_together_address, privacy: 'public', primary_flag: true)
        building = create(:better_together_infrastructure_building, privacy: 'public', address:)
        BetterTogether::Infrastructure::BuildingConnection.create!(building:, connection: community, position: 1,
                                                                   primary_flag: true)
        building.geospatial_space.space.assign_attributes(latitude: 48.95, longitude: -57.95)
        building.geospatial_space.save!
      end

      map = described_class.new
      map.visible_scope = BetterTogether::Community.where(id: shown.id)

      expect(map.records.map(&:id)).to eq([shown.id])
    end
  end
end
