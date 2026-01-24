# frozen_string_literal: true

module BetterTogether
  # Polymorphic recurrence model for schedulable resources
  # Stores ice_cube recurrence rules and manages recurring schedules
  class Recurrence < ApplicationRecord
    belongs_to :schedulable, polymorphic: true

    validates :rule, presence: true
    validates :frequency, inclusion: { in: %w[daily weekly monthly yearly], allow_nil: true }
    validate :validate_rule_format

    before_validation :extract_frequency_from_rule

    # Get the ice_cube schedule object from the rule
    # @return [IceCube::Schedule, nil]
    def schedule
      return nil if rule.blank?

      @schedule ||= IceCube::Schedule.from_yaml(rule)
    end

    # Check if this is a recurring schedule
    # @return [Boolean]
    def recurring?
      rule.present?
    end

    # Get occurrences between two dates
    # @param start_date [Date, Time] Start of range
    # @param end_date [Date, Time] End of range
    # @return [Array<Time>] Array of occurrence times
    def occurrences_between(start_date, end_date)
      return [] unless schedule

      schedule.occurrences_between(start_date, end_date).reject do |occurrence|
        exception_dates.include?(occurrence.to_date)
      end
    end

    # Get the next occurrence after a given time
    # @param after [Time] Time to start searching from (defaults to now)
    # @return [Time, nil] Next occurrence time or nil
    def next_occurrence(after: Time.current)
      return nil unless schedule

      occurrence = schedule.next_occurrence(after)
      return nil if occurrence.nil?
      return nil if ends_on && occurrence.to_date > ends_on
      return occurrence unless exception_dates.include?(occurrence.to_date)

      # Find next occurrence that's not an exception
      next_occurrence(after: occurrence + 1.second)
    end

    # Add an exception date (date when recurrence should not occur)
    # @param date [Date] Date to exclude
    def add_exception_date(date)
      self.exception_dates ||= []
      self.exception_dates << date unless exception_dates.include?(date)
    end

    # Remove an exception date
    # @param date [Date] Date to remove from exceptions
    def remove_exception_date(date)
      self.exception_dates ||= []
      exception_dates.delete(date)
    end

    private

    # Validate that the rule is valid ice_cube YAML
    def validate_rule_format
      return if rule.blank?

      IceCube::Schedule.from_yaml(rule)
    rescue StandardError => e
      errors.add(:rule, "is invalid: #{e.message}")
    end

    # Extract frequency from the ice_cube rule for quick queries
    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
    def extract_frequency_from_rule
      return if rule.blank?

      schedule_obj = IceCube::Schedule.from_yaml(rule)
      rrules = schedule_obj.rrules
      return if rrules.empty?

      # Get the first rrule's frequency
      first_rule = rrules.first
      self.frequency = case first_rule
                       when IceCube::DailyRule
                         'daily'
                       when IceCube::WeeklyRule
                         'weekly'
                       when IceCube::MonthlyRule
                         'monthly'
                       when IceCube::YearlyRule
                         'yearly'
                       end
    rescue StandardError
      # If we can't extract frequency, leave it nil
      nil
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength
  end
end
