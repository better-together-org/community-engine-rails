# frozen_string_literal: true

module BetterTogether
  # Expands a collection of Events into a flat list for a calendar grid:
  # non-recurring events pass through untouched, recurring events are
  # replaced by one override-aware Occurrence per date within the given
  # window (via RecurringSchedulable#occurrences_between, which already
  # merges in any persisted EventOccurrence override/cancellation and skips
  # nothing — cancelled dates are included so the grid can show a "Cancelled"
  # indicator). The result is what simple_calendar's `events:` collection
  # should receive so a recurring event renders on every occurrence date
  # instead of only its original starts_at.
  class CalendarOccurrenceExpander
    def self.call(events:, window_start:, window_end:)
      new(events:, window_start:, window_end:).call
    end

    def initialize(events:, window_start:, window_end:)
      @events = events
      @window_start = window_start
      @window_end = window_end
    end

    def call
      @events.flat_map do |event|
        event.recurring? ? event.occurrences_between(@window_start, @window_end) : [event]
      end
    end
  end
end
