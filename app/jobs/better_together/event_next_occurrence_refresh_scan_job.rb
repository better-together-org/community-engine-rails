# frozen_string_literal: true

module BetterTogether
  # Advances Event#next_occurrence_at for recurring events whose stored value
  # has passed — handles the passage of time itself, complementing the
  # immediate refresh already triggered by Event's own after_save and
  # Recurrence's/EventOccurrence's after_commit callbacks whenever something
  # actually changes. Mirrors EventReminderScanJob's shape: find_each with a
  # per-record rescue so one bad record never aborts the batch.
  class EventNextOccurrenceRefreshScanJob < ApplicationJob
    queue_as :maintenance

    # joins(:recurrence) scopes to recurring events only — a non-recurring
    # event's next_occurrence_at is its own starts_at and never needs
    # refreshing; it's correct to stay in the past forever once the event
    # itself is past.
    def perform
      scope = BetterTogether::Event.joins(:recurrence)
                                   .where(BetterTogether::Event.arel_table[:next_occurrence_at].lteq(Time.current))

      scope.find_each do |event|
        event.refresh_next_occurrence_at!
      rescue StandardError => e
        Rails.logger.error "Failed to refresh next_occurrence_at for event #{event&.id}: #{e.message}"
      end
    end
  end
end
