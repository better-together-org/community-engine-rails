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

  describe 'SEEDED_LEVELS' do
    it 'covers all five geography hierarchy classes' do
      expect(described_class::SEEDED_LEVELS).to contain_exactly(
        BetterTogether::Geography::Continent, BetterTogether::Geography::Country,
        BetterTogether::Geography::State, BetterTogether::Geography::Region,
        BetterTogether::Geography::Settlement
      )
    end
  end

  describe '.import_all_missing' do
    it 'iterates all 5 hierarchy classes, skipping records that are already geocoded' do
      geocoded = create(:geography_settlement, :without_country, :without_state)
      geocoded.space.latitude = 48.95
      geocoded.space.longitude = -57.95
      geocoded.save!

      ungeocoded = create(:geography_region, :without_country, :without_state)

      allow(described_class).to receive(:perform_now).and_call_original
      expect(described_class).to receive(:perform_now).with(ungeocoded)
      expect(described_class).not_to receive(:perform_now).with(geocoded)

      summary = described_class.import_all_missing

      expect(summary).to eq(imported: 1, skipped: 1, failed: 0)
    end
  end

  describe '.perform_with_retries' do
    let(:settlement) { create(:geography_settlement, :without_country, :without_state) }

    it 'retries in-process on a transient failure and succeeds without touching ActiveJob retry_on' do
      call_count = 0
      allow(described_class).to receive(:perform_now) do |_record|
        call_count += 1
        raise StandardError, 'transient' if call_count < 2
      end
      allow(described_class).to receive(:sleep)

      result = described_class.perform_with_retries(settlement)

      expect(result).to be true
      expect(call_count).to eq(2)
    end

    it 'gives up and returns false after exhausting attempts, without raising' do
      allow(described_class).to receive(:perform_now).and_raise(StandardError, 'persistent')
      allow(described_class).to receive(:sleep)

      result = nil
      expect { result = described_class.perform_with_retries(settlement, attempts: 2) }.not_to raise_error
      expect(result).to be false
      expect(described_class).to have_received(:perform_now).twice
    end
  end
end
