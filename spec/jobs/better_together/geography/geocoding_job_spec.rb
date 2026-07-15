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

    it 'triggers geographic hierarchy resolution when the geocodable supports it' do
      geocodable = double('geocodable')
      allow(geocodable).to receive(:geocode).and_return([47.5, -52.7])
      allow(geocodable).to receive(:save)
      allow(geocodable).to receive(:resolve_geographic_hierarchy!)

      job.perform(geocodable)

      expect(geocodable).to have_received(:resolve_geographic_hierarchy!)
    end

    it 'does not raise when the geocodable does not support hierarchy resolution' do
      geocodable = double('geocodable')
      allow(geocodable).to receive(:geocode).and_return([47.5, -52.7])
      allow(geocodable).to receive(:save)

      expect { job.perform(geocodable) }.not_to raise_error
    end

    it 'stashes the raw geocode result onto space.metadata when supported' do
      address = create(:better_together_address, line1: '1 Main St', city_name: 'Corner Brook')
      stub_result = instance_double(Geocoder::Result::Test, data: { 'country_code' => 'CA' })
      allow(address).to receive(:geocode).and_return([48.95, -57.95])
      allow(Geocoder).to receive(:search).and_return([stub_result])

      job.perform(address)

      expect(address.space.reload.metadata['geocode']).to eq('country_code' => 'CA')
    end
    # rubocop:enable RSpec/VerifiedDoubles
  end
end
