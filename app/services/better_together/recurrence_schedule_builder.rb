# frozen_string_literal: true

module BetterTogether
  # Builds an IceCube::Schedule from the recurrence form's flat attributes
  # (frequency/interval/weekdays/end_type/count). Shared by EventsController's
  # create/update path and the recurrence_preview endpoint so the two can
  # never drift apart, and so weekday index<->symbol conversion lives in one
  # place instead of being duplicated (and mismatched) across the controller
  # and the form view.
  class RecurrenceScheduleBuilder
    DAY_SYMBOLS = %i[sunday monday tuesday wednesday thursday friday saturday].freeze

    Result = Struct.new(:schedule, :errors, keyword_init: true) do
      def valid?
        errors.empty?
      end
    end

    # @param day_symbol [Symbol] e.g. :monday
    # @return [Integer, nil] matching checkbox index (0=Sunday..6=Saturday)
    def self.day_index_for(day_symbol)
      DAY_SYMBOLS.index(day_symbol)
    end

    # @param recurrence [BetterTogether::Recurrence]
    # @return [Array<Integer>] weekday checkbox indices for the recurrence's
    #   current weekdays, for pre-checking the edit form
    def self.weekday_indices_for(recurrence)
      return [] unless recurrence

      recurrence.weekdays.filter_map { |day_symbol| day_index_for(day_symbol) }
    end

    def initialize(start_time:, attrs:)
      @start_time = start_time
      @attrs = attrs || {}
      @errors = []
    end

    # @return [Result] schedule will be nil if errors is non-empty
    def build
      rule = build_rule
      return Result.new(schedule: nil, errors: @errors) if @errors.any? || rule.nil?

      schedule = IceCube::Schedule.new(@start_time)
      schedule.add_recurrence_rule(rule)
      Result.new(schedule: schedule, errors: @errors)
    end

    private

    def build_rule
      rule = case @attrs[:frequency]
             when 'daily' then IceCube::Rule.daily(interval)
             when 'weekly' then build_weekly_rule
             when 'monthly' then IceCube::Rule.monthly(interval)
             when 'yearly' then IceCube::Rule.yearly(interval)
             else
               @errors << :frequency_invalid
               nil
             end

      rule = apply_end_condition(rule) if rule
      rule
    end

    def interval
      value = @attrs[:interval].to_i
      value.positive? ? value : 1
    end

    def build_weekly_rule
      rule = IceCube::Rule.weekly(interval)

      Array.wrap(@attrs[:weekdays]).each do |day_index|
        next if day_index.blank?

        day_symbol = DAY_SYMBOLS[day_index.to_i]
        rule = rule.day(day_symbol) if day_symbol
      end

      rule
    end

    # Selecting an end type without its paired value used to be silently
    # discarded (the rule quietly became "never ends"). Surface it as a
    # real error instead so the form can report it.
    def apply_end_condition(rule)
      case @attrs[:end_type]
      when 'until' then apply_until_condition(rule)
      when 'count' then apply_count_condition(rule)
      end

      rule
    end

    def apply_until_condition(rule)
      return @errors << :ends_on_blank if @attrs[:ends_on].blank?

      ends_on = parse_ends_on
      rule.until(ends_on) if ends_on
    end

    def apply_count_condition(rule)
      return @errors << :count_blank if @attrs[:count].blank?

      rule.count(@attrs[:count].to_i)
    end

    def parse_ends_on
      Date.parse(@attrs[:ends_on].to_s)
    rescue ArgumentError, TypeError
      @errors << :ends_on_invalid
      nil
    end
  end
end
