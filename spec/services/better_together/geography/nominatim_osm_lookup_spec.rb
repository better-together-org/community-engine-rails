# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::NominatimOsmLookup do
  describe '.osm_id_for' do
    it 'builds the Nominatim id for each OpenStreetMap object type', :aggregate_failures do
      expect(described_class.osm_id_for('relation', 2_845_280)).to eq('R2845280')
      expect(described_class.osm_id_for('way', 5)).to eq('W5')
      expect(described_class.osm_id_for('node', 7)).to eq('N7')
    end

    it 'is nil for an unknown type or a missing id', :aggregate_failures do
      expect(described_class.osm_id_for('area', 1)).to be_nil
      expect(described_class.osm_id_for('relation', nil)).to be_nil
    end
  end

  describe 'the request' do
    subject(:url) do
      query = Geocoder::Query.new('R2845280', params: { polygon_geojson: 1 })
      described_class.new.send(:query_url, query)
    end

    it 'goes to /lookup with the id and the extra params', :aggregate_failures do
      expect(url).to include('/lookup?')
      expect(url).to include('osm_ids=R2845280')
      expect(url).to include('polygon_geojson=1')
      expect(url).not_to include('/search')
    end
  end
end
