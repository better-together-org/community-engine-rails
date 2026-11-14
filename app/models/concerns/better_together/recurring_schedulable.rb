# frozen_string_literal: true

module BetterTogether
  # Concern for models that can have recurring schedules
  # Provides interface for managing recurrence patterns
  module RecurringSchedulable
    extend ActiveSupport::Concern

    included do
      has_one :recurrence, as: :schedulable, class_name: 'BetterTogether::Recurrence', dependent: :destroy
      accepts_nested_attributes_for :recurrence, allow_destroy: true
    end

    # Check if this resource has a recurring schedule
    # @return [Boolean]
    def recurring?
      recurrence&.recurring? || false
    end

    # Get the ice_cube schedule for this resource
    # @return [IceCube::Schedule, nil]
    def schedule
      recurrence&.schedule
    end

    # Get occurrences between two dates. Override-aware: a date with a
    # persisted per-occurrence override (EventOccurrence) reflects its
    # effective values. Cancelled dates are INCLUDED (Occurrence#cancelled?
    # is true) rather than omitted — a display like the calendar grid or
    # event show page needs to render "this session is cancelled," not
    # silently show nothing, which would look identical to "never scheduled."
    # Callers that need "what actually happens next" (e.g. next_occurrence,
    # below) skip cancelled dates instead.
    # @param start_date [Date, Time] Start of range
    # @param end_date [Date, Time] End of range
    # @return [Array<Occurrence>] Array of occurrence objects
    def occurrences_between(start_date, end_date)
      return [self] unless recurring?

      recurrence.occurrences_between(start_date, end_date).map do |occurrence_time|
        build_occurrence_for(occurrence_time)
      end
    end

    # Get the next occurrence after a given time. Skips any date whose
    # per-occurrence override has been cancelled (a cancelled session isn't
    # a meaningful "next occurrence" for sorting/upcoming-list purposes),
    # and merges in an override's effective values for the date it does
    # return.
    # @param after [Time] Time to start searching from (defaults to now)
    # @return [Occurrence, nil] Next occurrence or nil
    def next_occurrence(after: Time.current)
      return nil unless recurring?

      current_after = after
      # Bounded like Recurrence#next_occurrence's own internal guard — a
      # pathological run of consecutive cancelled dates should not hang.
      1000.times do
        occurrence_time = recurrence.next_occurrence(after: current_after)
        return nil if occurrence_time.nil?

        built = build_occurrence_for(occurrence_time)
        return built unless built.cancelled?

        current_after = occurrence_time + 1.second
      end
      nil
    end

    # Create a recurrence for this resource
    # @param rule [String] IceCube YAML rule
    # @param ends_on [Date, nil] Optional end date
    # @return [Recurrence]
    def create_recurrence!(rule:, ends_on: nil)
      build_recurrence(rule: rule, ends_on: ends_on).tap(&:save!)
    end

    private

    # @param occurrence_time [Time, IceCube::Occurrence]
    # @return [Occurrence] always returns one, even for a cancelled date —
    #   see Occurrence#cancelled? for how callers should handle that case
    def build_occurrence_for(occurrence_time)
      # .to_time: Recurrence#next_occurrence/#occurrences_between return
      # IceCube::Occurrence — a SimpleDelegator around Time that behaves like
      # one almost everywhere but isn't a literal ::Time instance (breaks
      # strict type-checks, e.g. the Postgres adapter when persisting).
      # Coerce here, the one place these values enter a BetterTogether::Occurrence,
      # so every consumer of Occurrence#starts_at genuinely holds a real Time.
      real_time = occurrence_time.to_time
      existing = respond_to?(:event_occurrences) ? event_occurrences.find_by(occurrence_date: real_time.to_date) : nil

      Occurrence.new(self, real_time, override: existing)
    end
  end
end
