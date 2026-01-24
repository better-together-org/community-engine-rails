# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe EventOccurrence do
    let(:event) do
      create(:event,
             name: 'Weekly Meeting',
             starts_at: Time.zone.parse('2026-01-30 14:00'),
             duration_minutes: 60,
             timezone: 'America/New_York')
    end
    let(:occurrence_time) { Time.zone.parse('2026-02-06 14:00') }
    let(:occurrence) { described_class.new(event, occurrence_time) }

    describe 'initialization' do
      it 'sets parent_event and starts_at' do
        expect(occurrence.parent_event).to eq(event)
        expect(occurrence.starts_at).to eq(occurrence_time)
      end
    end

    describe 'attribute delegation' do
      it 'delegates name to parent event' do
        expect(occurrence.name).to eq(event.name)
      end

      it 'delegates timezone to parent event' do
        expect(occurrence.timezone).to eq(event.timezone)
      end

      it 'delegates duration_minutes to parent event' do
        expect(occurrence.duration_minutes).to eq(event.duration_minutes)
      end
    end

    describe '#ends_at' do
      it 'calculates end time based on duration' do
        expected_end = occurrence_time + 60.minutes

        expect(occurrence.ends_at).to eq(expected_end)
      end

      it 'memoizes the result' do
        ends_at1 = occurrence.ends_at
        ends_at2 = occurrence.ends_at

        expect(ends_at1.object_id).to eq(ends_at2.object_id)
      end
    end

    describe '#exception?' do
      it 'returns true if occurrence is on an exception date' do
        event.recurrence_exception_dates = [occurrence_time.to_date]

        expect(occurrence).to be_exception
      end

      it 'returns false if occurrence is not on an exception date' do
        event.recurrence_exception_dates = []

        expect(occurrence).not_to be_exception
      end
    end

    describe '#local_starts_at' do
      it 'returns start time in event timezone' do
        local_time = occurrence.local_starts_at

        expect(local_time.zone).to eq('EST')
      end
    end

    describe '#local_ends_at' do
      it 'returns end time in event timezone' do
        local_time = occurrence.local_ends_at

        expect(local_time.zone).to eq('EST')
      end
    end

    describe '#past?' do
      it 'returns true for past occurrences' do
        past_occurrence = described_class.new(event, 1.week.ago)

        expect(past_occurrence).to be_past
      end

      it 'returns false for future occurrences' do
        future_occurrence = described_class.new(event, 1.week.from_now)

        expect(future_occurrence).not_to be_past
      end
    end

    describe '#upcoming?' do
      it 'returns true for future occurrences' do
        future_occurrence = described_class.new(event, 1.week.from_now)

        expect(future_occurrence).to be_upcoming
      end

      it 'returns false for past occurrences' do
        past_occurrence = described_class.new(event, 1.week.ago)

        expect(past_occurrence).not_to be_upcoming
      end
    end

    describe '#happening_now?' do
      it 'returns true when current time is between start and end' do
        now = Time.current
        current_occurrence = described_class.new(event, now - 30.minutes)

        expect(current_occurrence).to be_happening_now
      end

      it 'returns false when current time is before start' do
        future_occurrence = described_class.new(event, 1.hour.from_now)

        expect(future_occurrence).not_to be_happening_now
      end

      it 'returns false when current time is after end' do
        past_occurrence = described_class.new(event, 2.hours.ago)

        expect(past_occurrence).not_to be_happening_now
      end
    end

    describe '#to_s' do
      it 'returns formatted occurrence description' do
        expected = "Weekly Meeting on #{occurrence_time.strftime('%Y-%m-%d %H:%M')}"

        expect(occurrence.to_s).to eq(expected)
      end
    end

    describe '#uid' do
      it 'generates unique identifier combining event ID and time' do
        expected_uid = "#{event.id}-#{occurrence_time.to_i}"

        expect(occurrence.uid).to eq(expected_uid)
      end

      it 'generates different UIDs for different occurrences' do
        occurrence1 = described_class.new(event, occurrence_time)
        occurrence2 = described_class.new(event, occurrence_time + 1.day)

        expect(occurrence1.uid).not_to eq(occurrence2.uid)
      end
    end
  end
end
