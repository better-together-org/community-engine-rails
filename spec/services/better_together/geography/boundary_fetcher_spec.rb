# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::BoundaryFetcher do
  let(:state) { create(:geography_state, name: 'Newfoundland and Labrador') }
  let(:country) { create(:geography_country, name: 'Canada') }
  let(:settlement) { create(:geography_settlement, name: 'Corner Brook', state:, country:) }
  let(:polygon) { { 'type' => 'Polygon', 'coordinates' => [[[-58.0, 48.9], [-57.9, 48.9], [-57.9, 49.0], [-58.0, 48.9]]] } }

  def result(data)
    instance_double(Geocoder::Result::Test, data:)
  end

  def hit(category:, geojson: polygon, osm_id: 1)
    result('category' => category, 'osm_type' => 'relation', 'osm_id' => osm_id, 'geojson' => geojson)
  end

  describe '#search_text' do
    it 'appends the parents so a common name is not ambiguous' do
      expect(described_class.new(settlement).search_text).to eq('Corner Brook, Newfoundland and Labrador, Canada')
    end

    it 'is just the name for a record without parents' do
      expect(described_class.new(create(:geography_country, name: 'Canada')).search_text).to eq('Canada')
    end
  end

  describe 'searching by name' do
    it 'asks for simplified polygons with the record context', :aggregate_failures do
      allow(Geocoder).to receive(:search).and_return([hit(category: 'boundary')])

      described_class.call(settlement)

      expect(Geocoder).to have_received(:search).with(
        'Corner Brook, Newfoundland and Labrador, Canada',
        params: { polygon_geojson: 1, polygon_threshold: 0.0005, limit: 5 }
      )
    end

    it 'uses the threshold it is given' do
      allow(Geocoder).to receive(:search).and_return([])

      described_class.call(settlement, threshold: 0.01)

      expect(Geocoder).to have_received(:search).with(anything, params: hash_including(polygon_threshold: 0.01))
    end

    it 'skips point results and prefers an administrative boundary over another polygon', :aggregate_failures do
      point = hit(category: 'place', geojson: { 'type' => 'Point', 'coordinates' => [-57.9, 48.9] }, osm_id: 1)
      park = hit(category: 'leisure', osm_id: 2)
      boundary = hit(category: 'boundary', osm_id: 3)
      allow(Geocoder).to receive(:search).and_return([point, park, boundary])

      fetched = described_class.call(settlement)

      expect(fetched.data['osm_id']).to eq(3)
      expect(fetched.via).to eq(:search)
    end

    it 'ignores polygons of the wrong kind, such as a post office returned for an informal region', :aggregate_failures do
      allow(Geocoder).to receive(:search).and_return([hit(category: 'amenity')])

      expect(described_class.call(settlement)).to have_attributes(data: nil, reason: :no_polygon)
    end

    it 'accepts a natural feature when there is no administrative boundary' do
      allow(Geocoder).to receive(:search).and_return([hit(category: 'natural', osm_id: 8)])

      expect(described_class.call(settlement).data['osm_id']).to eq(8)
    end

    it 'ignores a polygon whose bounding box is nowhere near the record', :aggregate_failures do
      settlement.space.update!(latitude: 48.95, longitude: -57.95)
      far = hit(category: 'boundary').tap { |r| r.data['boundingbox'] = %w[10.0 11.0 20.0 21.0] }
      near = hit(category: 'boundary', osm_id: 9).tap { |r| r.data['boundingbox'] = %w[48.9 49.0 -58.0 -57.9] }
      allow(Geocoder).to receive(:search).and_return([far, near])

      expect(described_class.call(settlement).data['osm_id']).to eq(9)
    end

    it 'reports no polygon when only points come back' do
      point = hit(category: 'place', geojson: { 'type' => 'Point', 'coordinates' => [-57.9, 48.9] })
      allow(Geocoder).to receive(:search).and_return([point])

      expect(described_class.call(settlement)).to have_attributes(data: nil, reason: :no_polygon)
    end

    it 'reports no result when nothing comes back' do
      allow(Geocoder).to receive(:search).and_return([])

      expect(described_class.call(settlement)).to have_attributes(data: nil, reason: :no_result)
    end
  end

  describe 'looking up the recorded OpenStreetMap object' do
    let(:lookup) { instance_double(BetterTogether::Geography::NominatimOsmLookup) }

    before do
      settlement.space.update!(metadata: { 'boundary_source' => { 'osm_type' => 'relation', 'osm_id' => 2_845_280 } })
      allow(BetterTogether::Geography::NominatimOsmLookup).to receive(:new).and_return(lookup)
    end

    it 'fetches that exact object by id instead of searching', :aggregate_failures do
      allow(lookup).to receive(:search).and_return([hit(category: 'boundary', osm_id: 2_845_280)])
      allow(Geocoder).to receive(:search)

      fetched = described_class.call(settlement)

      expect(lookup).to have_received(:search).with('R2845280', params: { polygon_geojson: 1, polygon_threshold: 0.0005 })
      expect(fetched).to have_attributes(via: :osm_id, data: hash_including('osm_id' => 2_845_280))
      expect(Geocoder).not_to have_received(:search)
    end

    it 'falls back to the name search when the object has no polygon any more' do
      allow(lookup).to receive(:search).and_return([])
      allow(Geocoder).to receive(:search).and_return([hit(category: 'boundary')])

      expect(described_class.call(settlement).via).to eq(:search)
    end
  end
end
