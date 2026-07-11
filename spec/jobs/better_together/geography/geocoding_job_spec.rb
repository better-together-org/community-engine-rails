# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::GeocodingJob do
  subject(:job) { described_class.new }

  describe 'queue configuration' do
    it 'uses the geocoding queue' do
      expect(described_class.queue_name).to eq('geocoding')
    end
  end

  describe '#perform' do
    # rubocop:disable RSpec/VerifiedDoubles
    it 'calls geocode on the geocodable object' do
      geocodable = double('geocodable')
      allow(geocodable).to receive(:geocode).and_return(nil)

      job.perform(geocodable)

      expect(geocodable).to have_received(:geocode)
    end

    it 'saves the geocodable when coordinates are returned' do
      geocodable = double('geocodable')
      allow(geocodable).to receive(:geocode).and_return([47.5, -52.7])
      allow(geocodable).to receive(:save)

      job.perform(geocodable)

      expect(geocodable).to have_received(:save)
    end

    it 'does not save when geocode returns nil' do
      geocodable = double('geocodable')
      allow(geocodable).to receive(:geocode).and_return(nil)
      allow(geocodable).to receive(:save)

      job.perform(geocodable)

      expect(geocodable).not_to have_received(:save)
    end
    # rubocop:enable RSpec/VerifiedDoubles
  end
end
