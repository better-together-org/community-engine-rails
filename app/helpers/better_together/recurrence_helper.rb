# frozen_string_literal: true

module BetterTogether
  # Helper methods for rendering recurrence forms and displaying recurrence rules
  module RecurrenceHelper
    FREQUENCIES = {
      daily: 'Daily',
      weekly: 'Weekly',
      monthly: 'Monthly',
      yearly: 'Yearly'
    }.freeze

    # Options for recurrence frequency select
    # @return [Array<Array<String, Symbol>>] Array of [label, value] pairs
    def recurrence_frequency_options
      FREQUENCIES.map { |key, value| [value, key] }
    end

    # Options for recurrence end type select
    # @return [Array<Array<String, String>>] Array of [label, value] pairs
    def recurrence_end_type_options
      [
        ['Never', 'never'],
        ['On date', 'until'],
        ['After occurrences', 'count']
      ]
    end

    # Generate checkboxes for weekday selection
    # @param form [ActionView::Helpers::FormBuilder] The form builder
    # @param selected_days [Array<Integer>] Array of selected day indices (0=Sunday, 6=Saturday)
    # @return [ActiveSupport::SafeBuffer] HTML safe string of checkboxes
    def weekday_checkboxes(form, selected_days: []) # rubocop:disable Metrics/MethodLength
      Date::DAYNAMES.map.with_index do |day, index|
        checked = selected_days.include?(index)
        content_tag(:div, class: 'form-check form-check-inline') do
          concat(
            check_box_tag(
              "#{form.object_name}[weekdays][]",
              index,
              checked,
              class: 'form-check-input',
              id: "#{form.object_name}_weekdays_#{index}"
            )
          )
          concat(
            label_tag(
              "#{form.object_name}_weekdays_#{index}",
              day,
              class: 'form-check-label'
            )
          )
        end
      end.join.html_safe
    end

    # Format a recurrence rule for display
    # @param recurrence [BetterTogether::Recurrence] The recurrence object
    # @return [String] Human-readable recurrence summary
    def format_recurrence_rule(recurrence)
      return 'Does not repeat' unless recurrence&.recurring?

      frequency = recurrence.frequency&.capitalize || 'Unknown'
      summary = frequency

      if recurrence.ends_on
        summary += " until #{l(recurrence.ends_on, format: :short)}"
      end

      summary
    end

    # Display next N occurrences
    # @param schedulable [Object] Object with RecurringSchedulable concern
    # @param count [Integer] Number of occurrences to show
    # @return [ActiveSupport::SafeBuffer] HTML safe string
    def next_occurrences_list(schedulable, count: 5)
      return content_tag(:p, 'Does not repeat', class: 'text-muted') unless schedulable.recurring?

      occurrences = schedulable.occurrences_between(Time.current, 1.year.from_now).take(count)

      content_tag(:ul, class: 'list-unstyled') do
        occurrences.map do |occurrence|
          content_tag(:li) do
            l(occurrence.starts_at, format: :long)
          end
        end.join.html_safe
      end
    end
  end
end
