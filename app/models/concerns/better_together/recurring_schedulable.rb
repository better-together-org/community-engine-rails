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

    # Get occurrences between two dates
    # @param start_date [Date, Time] Start of range
    # @param end_date [Date, Time] End of range
    # @return [Array<Occurrence>] Array of occurrence objects
    def occurrences_between(start_date, end_date)
      return [self] unless recurring?

      recurrence.occurrences_between(start_date, end_date).map do |occurrence_time|
        Occurrence.new(self, occurrence_time)
      end
    end

    # Get the next occurrence after a given time
    # @param after [Time] Time to start searching from (defaults to now)
    # @return [Occurrence, nil] Next occurrence or nil
    def next_occurrence(after: Time.current)
      return nil unless recurring?

      occurrence_time = recurrence.next_occurrence(after: after)
      occurrence_time ? Occurrence.new(self, occurrence_time) : nil
    end

    # Create a recurrence for this resource
    # @param rule [String] IceCube YAML rule
    # @param ends_on [Date, nil] Optional end date
    # @return [Recurrence]
    def create_recurrence!(rule:, ends_on: nil)
      build_recurrence(rule: rule, ends_on: ends_on).tap(&:save!)
    end
  end
end
