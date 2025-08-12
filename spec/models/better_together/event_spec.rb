# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Event, type: :model do # rubocop:todo Metrics/BlockLength
    subject(:event) { build(:event, name: 'Sample Event') }

    describe 'validations' do
      it { is_expected.to validate_presence_of(:name) }

      it 'allows valid registration URL' do
        event.registration_url = 'https://example.com/register'
        expect(event).to be_valid
      end

      it 'rejects invalid registration URL' do
        event.registration_url = 'not-a-valid-url'
        expect(event).to be_invalid
        expect(event.errors[:registration_url]).to be_present
      end

      it 'is invalid when ends_at precedes starts_at' do
        event.starts_at = 2.days.from_now
        event.ends_at = 1.day.from_now
        expect(event).to be_invalid
        expect(event.errors[:ends_at]).to be_present
      end
    end

    describe 'scopes' do
      let!(:past_event) { create(:event, name: 'Past Event', starts_at: 2.days.ago) }
      let!(:upcoming_event) { create(:event, name: 'Upcoming Event', starts_at: 2.days.from_now) }
      let!(:draft_event) { create(:event, name: 'Draft Event', starts_at: nil) }
      let!(:ongoing_event) do
        create(:event, name: 'Ongoing Event', starts_at: 1.day.ago, ends_at: 1.day.from_now)
      end

      it 'returns events starting in the future for upcoming' do
        expect(described_class.upcoming).to contain_exactly(upcoming_event)
      end

      it 'returns events that have started for past including ongoing ones' do
        expect(described_class.past).to match_array([past_event, ongoing_event])
      end

      it 'returns events without start time for draft' do
        expect(described_class.draft).to contain_exactly(draft_event)
      end
    end

    describe 'helper methods' do # rubocop:todo Metrics/BlockLength
      describe '#to_s' do
        it 'returns the event name' do
          expect(event.to_s).to eq('Sample Event')
        end
      end

      describe '#schedule_address_geocoding' do
        include ActiveJob::TestHelper

        before { ActiveJob::Base.queue_adapter = :test }

        it 'enqueues geocoding job when geocoding is needed' do
          allow(event).to receive(:should_geocode?).and_return(true)
          expect { event.schedule_address_geocoding }
            .to have_enqueued_job(BetterTogether::Geography::GeocodingJob)
        end

        it 'does not enqueue job when geocoding is not needed' do
          allow(event).to receive(:should_geocode?).and_return(false)
          expect { event.schedule_address_geocoding }
            .not_to have_enqueued_job(BetterTogether::Geography::GeocodingJob)
        end
      end

      describe '#should_geocode?' do # rubocop:todo Metrics/BlockLength
        context 'when geocoding string is blank' do
          before { allow(event).to receive(:geocoding_string).and_return(nil) }

          it 'returns false' do
            expect(event.should_geocode?).to be(false)
          end
        end

        context 'when address has changed' do
          before do
            allow(event).to receive(:geocoding_string).and_return('123 Main St')
            allow(event).to receive(:address_changed?).and_return(true)
          end

          it 'returns true' do
            expect(event.should_geocode?).to be(true)
          end
        end

        context 'when not geocoded yet' do
          before do
            allow(event).to receive(:geocoding_string).and_return('123 Main St')
            allow(event).to receive(:address_changed?).and_return(false)
            allow(event).to receive(:geocoded?).and_return(false)
          end

          it 'returns true' do
            expect(event.should_geocode?).to be(true)
          end
        end

        context 'when geocoded and address unchanged' do
          before do
            allow(event).to receive(:geocoding_string).and_return('123 Main St')
            allow(event).to receive(:address_changed?).and_return(false)
            allow(event).to receive(:geocoded?).and_return(true)
          end

          it 'returns false' do
            expect(event.should_geocode?).to be(false)
          end
        end
      end
    end
  end
end
