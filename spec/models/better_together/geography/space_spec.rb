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
end
