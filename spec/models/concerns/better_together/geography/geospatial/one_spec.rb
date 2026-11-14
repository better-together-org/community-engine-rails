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

  describe '#should_geocode?' do
    it 'returns true when this save changed the record, even if already geocoded ' \
       '(regression: changed? is always false by the time after_create/after_update ' \
       'fire, since Rails clears dirty state before those callbacks run - saved_changes? ' \
       'is the check that is actually still true at that point)' do
      address = create(:better_together_address)
      allow(address).to receive(:geocoded?).and_return(true)

      address.line1 = 'A brand new distinguishing address line'
      address.save!

      expect(address.should_geocode?).to be(true)
    end

    it 'returns false when this save changed nothing and the record is already geocoded' do
      address = create(:better_together_address)
      allow(address).to receive(:geocoded?).and_return(true)

      address.save!

      expect(address.should_geocode?).to be(false)
    end
  end

  describe '.without_auto_geocoding' do
    # class_methods (inside the concern) mix into includers, not into the concern
    # module itself — call through an actual includer. The underlying flag is a
    # single thread-local shared across every includer, so any includer works.
    let(:includer) { BetterTogether::Address }

    it 'suppresses should_geocode? for the duration of the block' do
      address = build(:better_together_address)

      includer.without_auto_geocoding do
        expect(includer.auto_geocoding_suppressed?).to be(true)
        expect(address.should_geocode?).to be(false)
      end
    end

    it 'un-suppresses after the block exits, even if it raises' do
      expect do
        includer.without_auto_geocoding { raise 'boom' }
      end.to raise_error('boom')

      expect(includer.auto_geocoding_suppressed?).to be(false)
    end

    it 'does not affect should_geocode? outside the block' do
      address = build(:better_together_address)

      includer.without_auto_geocoding { 1 }

      expect(includer.auto_geocoding_suppressed?).to be(false)
      expect(address.should_geocode?).to be(true)
    end
  end
end
