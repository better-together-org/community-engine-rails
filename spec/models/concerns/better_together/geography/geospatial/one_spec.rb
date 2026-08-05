# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::Geospatial::One do
  def schedule_geocoding_registered?(klass)
    klass._create_callbacks.any? { |cb| cb.filter == :schedule_geocoding } &&
      klass._update_callbacks.any? { |cb| cb.filter == :schedule_geocoding }
  end

  describe '.geocodes_self' do
    it 'registers the schedule_geocoding callbacks for includers that call it' do
      expect(schedule_geocoding_registered?(BetterTogether::Address)).to be(true)
      expect(schedule_geocoding_registered?(BetterTogether::Event)).to be(true)
    end

    it 'is not registered for includers that never call it' do
      expect(schedule_geocoding_registered?(BetterTogether::Infrastructure::Building)).to be(false)
      expect(schedule_geocoding_registered?(BetterTogether::Infrastructure::Floor)).to be(false)
      expect(schedule_geocoding_registered?(BetterTogether::Infrastructure::Room)).to be(false)
    end
  end

  describe '#geocoded?' do
    it 'is available on every includer regardless of geocodes_self, via the unconditional geocoded_by macro' do
      expect(BetterTogether::Infrastructure::Building.new).to respond_to(:geocoded?)
      expect(BetterTogether::Infrastructure::Floor.new).to respond_to(:geocoded?)
    end
  end
end
