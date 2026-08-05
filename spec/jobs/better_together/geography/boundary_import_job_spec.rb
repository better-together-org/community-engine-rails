# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::BoundaryImportJob do
  subject(:job) { described_class.new }

  let(:settlement) { create(:geography_settlement, name: 'Corner Brook') }

  let(:polygon_geojson) do
    {
      'type' => 'Polygon',
      'coordinates' => [[[-58.0, 48.9], [-57.9, 48.9], [-57.9, 49.0], [-58.0, 49.0], [-58.0, 48.9]]]
    }
  end

  let(:nominatim_result) do
    instance_double(
      Geocoder::Result::Test,
      data: { 'osm_type' => 'relation', 'osm_id' => 12_345, 'geojson' => polygon_geojson }
    )
  end

  describe 'HIERARCHY_LEVELS' do
    it 'matches Locatable::Many::LEVELS reversed to broadest-to-narrowest order' do
      expect(described_class::HIERARCHY_LEVELS).to eq(
        [BetterTogether::Geography::Continent, BetterTogether::Geography::Country,
         BetterTogether::Geography::State, BetterTogether::Geography::Region,
         BetterTogether::Geography::Settlement]
      )
    end
  end

  describe '#perform' do
    context 'when the record has no boundary yet' do
      it 'fetches, coerces to MultiPolygon, and stores provenance' do
        allow(Geocoder).to receive(:search).with('Corner Brook', params: { polygon_geojson: 1 })
                                           .and_return([nominatim_result])

        job.perform(settlement)
        settlement.space.reload

        expect(settlement.space.boundary).to be_a(RGeo::Feature::MultiPolygon)
        expect(settlement.space.metadata['boundary_source']).to include(
          'provider' => 'nominatim', 'osm_type' => 'relation', 'osm_id' => 12_345
        )
      end
    end

    context 'when the record already has a boundary' do
      it 'does not re-fetch' do
        settlement.space.boundary = square_boundary(center_lng: -57.95, center_lat: 48.95)
        settlement.save!

        expect(Geocoder).not_to receive(:search)

        job.perform(settlement)
      end

      it 'does re-fetch when force_refresh is true' do
        settlement.space.boundary = square_boundary(center_lng: -57.95, center_lat: 48.95)
        settlement.save!

        allow(Geocoder).to receive(:search).and_return([nominatim_result])

        job.perform(settlement, force_refresh: true)

        expect(Geocoder).to have_received(:search)
      end
    end

    context 'when Geocoder returns no result' do
      it 'does not raise and leaves boundary nil' do
        allow(Geocoder).to receive(:search).and_return([])

        expect { job.perform(settlement) }.not_to raise_error
        expect(settlement.space.boundary).to be_nil
      end
    end
  end

  describe '.import_all_missing' do
    it 'iterates all 5 hierarchy classes, skipping records that already have a boundary' do
      with_boundary = create(:geography_settlement, :without_country, :without_state)
      with_boundary.space.boundary = square_boundary(center_lng: -57.9, center_lat: 48.9)
      with_boundary.save!

      without_boundary = create(:geography_region, :without_country, :without_state)

      allow(described_class).to receive(:perform_now).and_call_original
      expect(described_class).to receive(:perform_now).with(without_boundary)
      expect(described_class).not_to receive(:perform_now).with(with_boundary)

      summary = described_class.import_all_missing

      expect(summary).to eq(imported: 1, skipped: 1, failed: 0)
    end
  end

  describe '.perform_with_retries' do
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
