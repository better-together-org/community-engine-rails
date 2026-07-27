# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe RecurrenceScheduleBuilder do
    let(:start_time) { Time.zone.parse('2026-02-22 10:00:00') } # a Sunday

    describe '#build' do
      it 'builds a daily schedule' do
        result = described_class.new(start_time:, attrs: { frequency: 'daily', interval: 1 }).build

        expect(result).to be_valid
        expect(result.schedule.occurrences_between(start_time, start_time + 3.days).length).to eq(4)
      end

      it 'defaults interval to 1 when blank rather than building an invalid interval of 0' do
        result = described_class.new(start_time:, attrs: { frequency: 'daily', interval: '' }).build

        expect(result).to be_valid
        expect(result.schedule.occurrences_between(start_time, start_time + 3.days).length).to eq(4)
      end

      it 'builds a weekly schedule restricted to specific weekdays' do
        result = described_class.new(
          start_time:, attrs: { frequency: 'weekly', interval: 1, weekdays: %w[1 3] }
        ).build

        expect(result).to be_valid
        occurrences = result.schedule.occurrences_between(start_time, start_time + 2.weeks)
        expect(occurrences.map(&:wday).uniq.sort).to eq([1, 3])
      end

      it 'applies a count end condition' do
        result = described_class.new(
          start_time:, attrs: { frequency: 'daily', interval: 1, end_type: 'count', count: 3 }
        ).build

        expect(result).to be_valid
        expect(result.schedule.occurrences_between(start_time, 1.year.from_now).length).to eq(3)
      end

      it 'applies an until end condition' do
        until_date = start_time.to_date + 5.days
        result = described_class.new(
          start_time:, attrs: { frequency: 'daily', interval: 1, end_type: 'until', ends_on: until_date.iso8601 }
        ).build

        expect(result).to be_valid
        occurrences = result.schedule.occurrences_between(start_time, 1.year.from_now)
        expect(occurrences.last.to_date).to be <= until_date
      end

      it 'reports an error instead of silently becoming never-ending when end_type is "until" with a blank ends_on' do
        result = described_class.new(
          start_time:, attrs: { frequency: 'weekly', interval: 1, end_type: 'until', ends_on: '' }
        ).build

        expect(result).not_to be_valid
        expect(result.errors).to eq([:ends_on_blank])
        expect(result.schedule).to be_nil
      end

      it 'reports an error instead of silently becoming never-ending when end_type is "count" with a blank count' do
        result = described_class.new(
          start_time:, attrs: { frequency: 'monthly', interval: 1, end_type: 'count', count: '' }
        ).build

        expect(result).not_to be_valid
        expect(result.errors).to eq([:count_blank])
      end

      it 'reports an error for an unparseable ends_on date rather than raising' do
        result = described_class.new(
          start_time:, attrs: { frequency: 'weekly', interval: 1, end_type: 'until', ends_on: 'not-a-date' }
        ).build

        expect(result).not_to be_valid
        expect(result.errors).to include(:ends_on_invalid)
      end
    end

    describe '.weekday_indices_for' do
      it 'returns an empty array for a nil recurrence' do
        expect(described_class.weekday_indices_for(nil)).to eq([])
      end

      it 'converts the real Symbol weekdays from a persisted Recurrence into checkbox indices' do
        result = described_class.new(
          start_time:, attrs: { frequency: 'weekly', interval: 1, weekdays: %w[1 3] }
        ).build
        # #weekdays only returns anything when frequency == 'weekly', and
        # frequency is normally extracted from the rule by a before_validation
        # callback — build_stubbed skips callbacks, so set it explicitly here
        # to reflect what a real persisted recurrence would have.
        recurrence = build_stubbed(:recurrence, rule: result.schedule.to_yaml, frequency: 'weekly')

        expect(described_class.weekday_indices_for(recurrence)).to contain_exactly(1, 3)
      end
    end
  end
end
