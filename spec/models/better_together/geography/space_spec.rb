# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::Space do
  subject(:space) { described_class.new }

  describe 'validations' do
    it 'is valid with no coordinates (all optional)' do
      expect(space).to be_valid
    end

    it 'allows valid latitude (0 degrees)' do
      space.latitude = 0
      expect(space).to be_valid
    end

    it 'allows valid latitude (boundary -90)' do
      space.latitude = -90
      expect(space).to be_valid
    end

    it 'allows valid latitude (boundary 90)' do
      space.latitude = 90
      expect(space).to be_valid
    end

    it 'rejects latitude below -90' do
      space.latitude = -91
      expect(space).not_to be_valid
    end

    it 'rejects latitude above 90' do
      space.latitude = 91
      expect(space).not_to be_valid
    end

    it 'allows valid longitude (-180)' do
      space.longitude = -180
      expect(space).to be_valid
    end

    it 'allows valid longitude (180)' do
      space.longitude = 180
      expect(space).to be_valid
    end

    it 'rejects longitude below -180' do
      space.longitude = -181
      expect(space).not_to be_valid
    end

    it 'rejects longitude above 180' do
      space.longitude = 181
      expect(space).not_to be_valid
    end

    it 'allows numeric elevation' do
      space.elevation = 500
      expect(space).to be_valid
    end

    it 'rejects non-numeric elevation' do
      space.elevation = 'high'
      expect(space).not_to be_valid
    end
  end

  describe '#to_rgeo_point' do
    it 'returns nil when not geocoded' do
      expect(space.to_rgeo_point).to be_nil
    end

    it 'returns an RGeo point built from longitude/latitude when geocoded' do
      space.latitude = 48.9517
      space.longitude = -57.9474

      point = space.to_rgeo_point

      expect(point).to be_a(RGeo::Feature::Point)
      expect(point.x).to eq(-57.9474)
      expect(point.y).to eq(48.9517)
    end
  end

  describe '#boundary' do
    it 'round-trips a MultiPolygon through save/reload' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      ring = factory.linear_ring([
                                   factory.point(-58.0, 48.9),
                                   factory.point(-57.9, 48.9),
                                   factory.point(-57.9, 49.0),
                                   factory.point(-58.0, 49.0),
                                   factory.point(-58.0, 48.9)
                                 ])
      boundary = factory.multi_polygon([factory.polygon(ring)])

      persisted = create(:geography_space, boundary:)
      persisted.reload

      expect(persisted.boundary).to be_a(RGeo::Feature::MultiPolygon)
    end
  end
end
