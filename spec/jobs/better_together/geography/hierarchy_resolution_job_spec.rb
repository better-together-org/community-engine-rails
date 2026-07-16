# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::HierarchyResolutionJob do
  subject(:job) { described_class.new }

  let(:corner_brook_lat) { 48.9517 }
  let(:corner_brook_lng) { -57.9474 }

  describe '#perform' do
    context 'when the locatable has no space' do
      it 'does nothing' do
        locatable = double('locatable') # rubocop:disable RSpec/VerifiedDoubles
        allow(locatable).to receive(:respond_to?).with(:space).and_return(false)

        expect { job.perform(locatable) }.not_to raise_error
      end
    end

    context 'when the locatable is not geocoded' do
      it 'does nothing' do
        address = create(:better_together_address, line1: nil, city_name: nil, country_name: nil, postal_code: nil)

        expect { job.perform(address) }.not_to raise_error
        expect(address.locatable_locations).to be_empty
      end
    end

    context 'when a point falls inside a settlement boundary' do
      it 'creates a settlement placement resolved via polygon containment' do
        settlement = create(:geography_settlement)
        settlement.space.boundary = square_boundary(center_lng: corner_brook_lng, center_lat: corner_brook_lat)
        settlement.save!

        address = create(:better_together_address)
        address.space.latitude = corner_brook_lat
        address.space.longitude = corner_brook_lng
        address.save!

        job.perform(address)

        placement = address.locatable_locations.find_by(location_type: 'BetterTogether::Geography::Settlement')
        expect(placement).to be_present
        expect(placement.location).to eq(settlement)
        expect(placement.resolution_method).to eq('polygon')
        expect(placement.resolved_at).to be_present
      end
    end

    context 'when a point falls outside every settlement boundary' do
      it 'creates no settlement placement' do
        settlement = create(:geography_settlement)
        settlement.space.boundary = square_boundary(center_lng: corner_brook_lng, center_lat: corner_brook_lat)
        settlement.save!

        address = create(:better_together_address)
        address.space.latitude = 10.0
        address.space.longitude = 10.0
        address.save!

        job.perform(address)

        expect(
          address.locatable_locations.find_by(location_type: 'BetterTogether::Geography::Settlement')
        ).to be_nil
      end
    end

    context 'when no polygon matches but geocode metadata has a country_code' do
      it 'resolves country via the iso_code fallback' do
        country = create(:geography_country, iso_code: 'CA')

        address = create(:better_together_address)
        address.space.latitude = corner_brook_lat
        address.space.longitude = corner_brook_lng
        address.space.metadata = { 'geocode' => { 'country_code' => 'ca' } }
        address.save!

        job.perform(address)

        placement = address.locatable_locations.find_by(location_type: 'BetterTogether::Geography::Country')
        expect(placement.location).to eq(country)
        expect(placement.resolution_method).to eq('iso_code')
      end

      it 'does not override a placement already resolved via polygon containment' do
        country = create(:geography_country, iso_code: 'CA')
        country.space.boundary = square_boundary(center_lng: corner_brook_lng, center_lat: corner_brook_lat,
                                                 radius_degrees: 5)
        country.save!
        other_country = create(:geography_country, iso_code: 'US')

        address = create(:better_together_address)
        address.space.latitude = corner_brook_lat
        address.space.longitude = corner_brook_lng
        address.space.metadata = { 'geocode' => { 'country_code' => 'us' } }
        address.save!

        job.perform(address)

        placement = address.locatable_locations.find_by(location_type: 'BetterTogether::Geography::Country')
        expect(placement.location).to eq(country)
        expect(placement.location).not_to eq(other_country)
        expect(placement.resolution_method).to eq('polygon')
      end
    end

    context 'when re-run on an already-resolved locatable' do
      it 'updates the existing placement rather than creating a duplicate' do
        settlement = create(:geography_settlement)
        settlement.space.boundary = square_boundary(center_lng: corner_brook_lng, center_lat: corner_brook_lat)
        settlement.save!

        address = create(:better_together_address)
        address.space.latitude = corner_brook_lat
        address.space.longitude = corner_brook_lng
        address.save!

        job.perform(address)
        expect do
          job.perform(address)
        end.not_to(change do
          address.locatable_locations.where(location_type: 'BetterTogether::Geography::Settlement').count
        end)
      end
    end
  end

  describe '.backfill_all_missing' do
    it 'enqueues geocoded, unresolved records and skips already-resolved ones' do
      geocoded_unresolved = create(:better_together_address)
      geocoded_unresolved.space.latitude = corner_brook_lat
      geocoded_unresolved.space.longitude = corner_brook_lng
      geocoded_unresolved.save!

      ungeocoded = create(:better_together_address)

      already_resolved = create(:better_together_address)
      already_resolved.space.latitude = corner_brook_lat
      already_resolved.space.longitude = corner_brook_lng
      already_resolved.save!
      BetterTogether::Geography::LocatableLocation.create!(
        locatable: already_resolved, location_type: 'BetterTogether::Geography::Country',
        location: create(:geography_country), resolution_method: 'iso_code', resolved_at: Time.current
      )

      summary = nil
      expect do
        summary = described_class.backfill_all_missing
      end.to have_enqueued_job(described_class).exactly(1).times.with(geocoded_unresolved)

      expect(summary).to eq(enqueued: 1)
      expect(ungeocoded.persisted?).to be true # exists but is never enqueued (not geocoded)
    end
  end
end
