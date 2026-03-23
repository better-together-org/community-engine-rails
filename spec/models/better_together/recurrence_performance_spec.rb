# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Recurrence do
  let(:starts_at) { Time.zone.parse('2026-02-01 10:00:00') }
  let(:ends_at) { starts_at + 2.hours }
  let(:event) { create(:event, starts_at:, ends_at:) }
  let(:recurrence) do
    schedule = IceCube::Schedule.new(event.starts_at)
    schedule.add_recurrence_rule(IceCube::Rule.daily)

    create(:recurrence,
           schedulable: event,
           frequency: 'daily',
           rule: schedule.to_yaml,
           ends_on: nil)
  end

  describe '#occurrences_between with exception dates' do
    context 'with 50 exception dates' do
      before do
        # Add 50 exception dates spread over 100 days
        50.times do |i|
          recurrence.add_exception_date((event.starts_at + (i * 2).days).to_date)
        end
        recurrence.save!
      end

      it 'efficiently filters occurrences using Set-based lookup' do
        start_time = Time.current

        # Get 100 days of occurrences
        occurrences = recurrence.occurrences_between(
          event.starts_at,
          event.starts_at + 100.days
        )

        elapsed = Time.current - start_time

        # Verify results exclude exception dates
        occurrence_dates = occurrences.map(&:to_date)
        expect(occurrence_dates & recurrence.exception_dates).to be_empty

        # Should have roughly 50 occurrences (100 days - 50 exceptions)
        expect(occurrences.length).to be_between(45, 55)

        # Performance assertion: Should complete quickly
        expect(elapsed).to be < 1.0 # Should complete in under 1 second
      end

      it 'excludes all exception dates from results' do
        occurrences = recurrence.occurrences_between(
          event.starts_at,
          event.starts_at + 100.days
        )

        # Verify no exception dates appear in results
        occurrence_dates = occurrences.map(&:to_date)
        exception_dates = recurrence.exception_dates

        expect(occurrence_dates & exception_dates).to be_empty
      end
    end

    context 'performance comparison documentation' do
      it 'documents the Set-based optimization' do
        # This test documents the performance improvement
        #
        # Array-based lookup (old implementation):
        #   exception_dates.include?(occurrence.to_date)
        #   Time Complexity: O(n) for each occurrence check
        #   Total: O(m * n) where m = occurrences, n = exception dates
        #   Example: 90 occurrences × 50 exceptions = 4,500 comparisons
        #
        # Set-based lookup (new implementation):
        #   exception_set = (exception_dates || []).to_set
        #   exception_set.include?(occurrence.to_date)
        #   Time Complexity: O(1) for each occurrence check
        #   Total: O(m) where m = occurrences
        #   Example: 90 occurrences = 90 comparisons
        #
        # Performance gain: ~50x improvement for 50 exception dates

        expect(recurrence.exception_dates).to respond_to(:to_set)
      end
    end
  end

  describe 'edge cases' do
    it 'handles empty exception dates array' do
      recurrence.update!(exception_dates: [])

      occurrences = recurrence.occurrences_between(
        event.starts_at,
        event.starts_at + 7.days
      )

      # Should return 8 daily occurrences (days 0-7 inclusive)
      expect(occurrences.length).to eq(8)
    end

    it 'handles nil exception dates' do
      recurrence.update!(exception_dates: nil)

      occurrences = recurrence.occurrences_between(
        event.starts_at,
        event.starts_at + 7.days
      )

      # Should handle gracefully and return 8 occurrences
      expect(occurrences.length).to eq(8)
    end
  end
end
