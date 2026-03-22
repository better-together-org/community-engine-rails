# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module BetterTogether
  RSpec.describe Occurrence do
    let(:event) do
      create(:event,
             name: 'Weekly Meeting',
             starts_at: Time.zone.parse('2026-01-15 14:00'),
             duration_minutes: 60)
    end
    let(:occurrence_time) { Time.zone.parse('2026-01-22 14:00') }
    let(:occurrence) { described_class.new(event, occurrence_time) }

    describe '#initialize' do
      it 'sets parent and starts_at' do
        expect(occurrence.parent).to eq(event)
        expect(occurrence.starts_at).to eq(occurrence_time)
      end
    end

    describe '#ends_at' do
      it 'calculates end time based on parent duration' do
        expected_end = occurrence_time + 60.minutes
        expect(occurrence.ends_at).to eq(expected_end)
      end

      it 'returns nil when parent has no duration' do
        # Create event with only starts_at (validation allows nil duration if starts_at is nil)
        event_without_duration = build_stubbed(:event,
                                               name: 'No Duration Event',
                                               starts_at: nil,
                                               duration_minutes: nil)
        occurrence_without_duration = described_class.new(event_without_duration, occurrence_time)
        expect(occurrence_without_duration.ends_at).to be_nil
      end
    end

    describe 'method delegation' do
      it 'delegates name to parent' do
        expect(occurrence.name).to eq('Weekly Meeting')
      end

      it 'delegates other methods to parent' do
        expect(occurrence.id).to eq(event.id)
        expect(occurrence.respond_to?(:timezone)).to be true
      end
    end

    describe '#date' do
      it 'returns the date of the occurrence' do
        expect(occurrence.date).to eq(Date.parse('2026-01-22'))
      end
    end

    describe '#on_date?' do
      it 'returns true when occurrence is on the given date' do
        expect(occurrence.on_date?(Date.parse('2026-01-22'))).to be true
      end

      it 'returns false when occurrence is not on the given date' do
        expect(occurrence.on_date?(Date.parse('2026-01-23'))).to be false
      end
    end

    describe '#past?' do
      it 'returns true for past occurrences' do
        past_occurrence = described_class.new(event, 1.day.ago)
        expect(past_occurrence).to be_past
      end

      it 'returns false for future occurrences' do
        future_occurrence = described_class.new(event, 1.day.from_now)
        expect(future_occurrence).not_to be_past
      end
    end

    describe '#future?' do
      it 'returns true for future occurrences' do
        future_occurrence = described_class.new(event, 1.day.from_now)
        expect(future_occurrence).to be_future
      end

      it 'returns false for past occurrences' do
        past_occurrence = described_class.new(event, 1.day.ago)
        expect(past_occurrence).not_to be_future
      end
    end

    describe '#today?' do
      it 'returns true when occurrence is today' do
        today_occurrence = described_class.new(event, Time.current)
        expect(today_occurrence).to be_today
      end

      it 'returns false when occurrence is not today' do
        tomorrow_occurrence = described_class.new(event, 1.day.from_now)
        expect(tomorrow_occurrence).not_to be_today
      end
    end

    describe '#to_h' do
      it 'returns hash representation' do
        hash = occurrence.to_h
        expect(hash[:starts_at]).to eq(occurrence_time)
        expect(hash[:ends_at]).to eq(occurrence_time + 60.minutes)
        expect(hash[:parent_id]).to eq(event.id)
        expect(hash[:parent_type]).to eq('BetterTogether::Event')
      end
    end

    describe '#to_s' do
      it 'returns string representation' do
        expect(occurrence.to_s).to include('BetterTogether::Event')
        expect(occurrence.to_s).to include('2026-01-22')
      end
    end

    describe 'equality' do
      let(:same_occurrence) { described_class.new(event, occurrence_time) }
      let(:different_occurrence) { described_class.new(event, occurrence_time + 1.week) }

      it 'considers occurrences with same parent and time equal' do
        expect(occurrence).to eq(same_occurrence)
      end

      it 'considers occurrences with different times not equal' do
        expect(occurrence).not_to eq(different_occurrence)
      end

      it 'supports hash-based collections' do
        set = Set.new([occurrence, same_occurrence, different_occurrence])
        expect(set.size).to eq(2) # same_occurrence is duplicate
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
