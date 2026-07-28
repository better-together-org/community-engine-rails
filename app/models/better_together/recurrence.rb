# frozen_string_literal: true

module BetterTogether
  # Polymorphic recurrence model for schedulable resources
  # Stores ice_cube recurrence rules and manages recurring schedules
  class Recurrence < ApplicationRecord # rubocop:todo Metrics/ClassLength
    belongs_to :schedulable, polymorphic: true

    # Transient, not persisted. Set by EventsController#process_recurrence_attributes
    # when the submitted end_type ('until'/'count') is missing its paired
    # ends_on/count value, so the form can surface a clear error instead of
    # silently saving the recurrence as "never ends".
    attr_accessor :end_condition_error

    # Transient, not persisted. Set when one or more submitted exception
    # dates could not be parsed, so the save is blocked with a real error
    # instead of the old behavior of silently dropping the bad entry.
    attr_accessor :exception_dates_error

    validates :rule, presence: true
    validates :frequency, inclusion: { in: %w[daily weekly monthly yearly], allow_nil: true }
    validate :validate_rule_format
    validate :validate_end_condition_present
    validate :validate_exception_dates_present

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

      # Use Set for O(1) lookup instead of O(n) array lookup
      # Handle nil exception_dates gracefully
      exception_set = (exception_dates || []).to_set
      schedule.occurrences_between(start_date, end_date).reject do |occurrence|
        exception_set.include?(occurrence.to_date)
      end
    end

    # Get the next occurrence after a given time
    # @param after [Time] Time to start searching from (defaults to now)
    # @return [Time, nil] Next occurrence time or nil
    def next_occurrence(after: Time.current) # rubocop:todo Metrics/AbcSize
      return nil unless schedule

      # Bounded iteration to prevent infinite loops
      # Limit to 1000 iterations - no valid recurrence should need more
      max_iterations = 1000
      current_time = after
      exception_set = (exception_dates || []).to_set

      max_iterations.times do
        occurrence = schedule.next_occurrence(current_time)
        return nil if occurrence.nil?
        return nil if ends_on && occurrence.to_date > ends_on
        return occurrence unless exception_set.include?(occurrence.to_date)

        # Move past this exception and continue searching
        current_time = occurrence + 1.second
      end

      # If we hit the limit, log a warning and return nil
      Rails.logger.warn("Recurrence#next_occurrence hit iteration limit for recurrence #{id}")
      nil
    end

    # Add an exception date (date when recurrence should not occur)
    # @param date [Date] Date to exclude
    def add_exception_date(date)
      self.exception_dates ||= []
      exception_dates << date unless exception_dates.include?(date)
    end

    # Remove an exception date
    # @param date [Date] Date to remove from exceptions
    def remove_exception_date(date)
      self.exception_dates ||= []
      exception_dates.delete(date)
    end

    # Extract interval from the IceCube rule
    # @return [Integer, nil]
    def interval
      return nil unless schedule&.rrules&.first

      schedule.rrules.first.validations[:interval]&.first || 1
    end

    # Extract weekdays from the IceCube rule (for weekly recurrence)
    # @return [Array<Symbol>]
    def weekdays
      return [] unless schedule&.rrules&.first
      return [] unless frequency == 'weekly'

      day_validations = schedule.rrules.first.validations[:day]
      return [] unless day_validations

      # IceCube's DayValidation#day is a plain Integer (0=Sunday..6=Saturday),
      # not a day-name string — `v.day.to_s.downcase.to_sym` used to turn 1
      # into :"1" instead of :monday, silently breaking every consumer that
      # expected real weekday symbols back.
      day_validations.filter_map { |v| BetterTogether::RecurrenceScheduleBuilder::DAY_SYMBOLS[v.day] }
    end

    # Extract end_type from recurrence data
    # @return [String] 'never', 'until', or 'count'
    def end_type
      return 'never' unless schedule&.rrules&.first

      rule = schedule.rrules.first
      return 'count' if rule.occurrence_count.present?
      return 'until' if rule.until_time.present? || ends_on.present?

      'never'
    end

    # Extract count from the IceCube rule
    # @return [Integer, nil]
    def count
      return nil unless schedule&.rrules&.first

      schedule.rrules.first.occurrence_count
    end

    private

    # Validate that the rule is valid ice_cube YAML
    def validate_rule_format
      return if rule.blank?

      IceCube::Schedule.from_yaml(rule)
    rescue StandardError => e
      errors.add(:rule, "is invalid: #{e.message}")
    end

    def validate_end_condition_present
      case end_condition_error
      when :ends_on_blank
        errors.add(:ends_on, :required_for_end_type, message: 'must be set when "On date" is selected as the end type')
      when :count_blank
        errors.add(:count, :required_for_end_type,
                   message: 'must be set when "After occurrences" is selected as the end type')
      when :ends_on_invalid
        errors.add(:ends_on, :invalid, message: 'is not a valid date')
      end
    end

    def validate_exception_dates_present
      return unless exception_dates_error

      errors.add(:exception_dates, :invalid, message: 'contains one or more dates that could not be understood')
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

    # Permitted attributes for mass assignment
    # @param id [Boolean] Whether to include :id
    # @param destroy [Boolean] Whether to include :_destroy
    # @return [Array<Symbol>] Array of permitted attribute names
    def self.permitted_attributes(id: false, destroy: false) # rubocop:disable Lint/IneffectiveAccessModifier
      attrs = %i[rule ends_on end_condition_error exception_dates_error]
      attrs << { exception_dates: [] } # Permit array of exception dates
      attrs << :id if id
      attrs << :_destroy if destroy
      attrs
    end
  end
end
