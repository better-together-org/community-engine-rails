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
      # form.object_name (e.g. "event[recurrence_attributes]") contains `[`/`]`
      # — technically legal in an id, but it broke label/for association for
      # axe-core and assistive tech, so checkboxes never had an accessible
      # name. Strip to a plain alphanumeric id base instead.
      id_base = "#{form.object_name.gsub(/\W+/, '_')}_weekdays"

      Date::DAYNAMES.map.with_index do |day, index|
        checked = selected_days.include?(index)
        checkbox_id = "#{id_base}_#{index}"

        content_tag(:div, class: 'form-check form-check-inline') do
          concat(
            check_box_tag(
              "#{form.object_name}[weekdays][]",
              index,
              checked,
              class: 'form-check-input',
              id: checkbox_id,
              data: { action: 'change->better-together--recurrence#fieldChanged' }
            )
          )
          concat(
            label_tag(
              checkbox_id,
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

    # Build a plain-English sentence describing a recurrence from the same
    # flat attrs hash EventsController/RecurrenceScheduleBuilder work from
    # (frequency/interval/weekdays/end_type/ends_on/count) — used by the
    # recurrence_preview endpoint so users can confirm the whole
    # configuration at a glance instead of parsing five separate fields.
    # @param attrs [Hash] frequency/interval/weekdays/end_type/ends_on/count
    # @return [String, nil] nil when no frequency is set at all
    def recurrence_attrs_summary(attrs) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      return nil if attrs[:frequency].blank?

      interval = attrs[:interval].to_i
      interval = 1 unless interval.positive?
      unit = t("better_together.events.recurrence.units.#{attrs[:frequency]}", default: attrs[:frequency].to_s)

      parts = [t('better_together.events.recurrence.summary.every', count: interval, unit: unit)]

      if attrs[:frequency].to_s == 'weekly'
        day_names = Array(attrs[:weekdays]).filter_map { |i| Date::DAYNAMES[i.to_i] }
        parts << t('better_together.events.recurrence.summary.on_days', days: day_names.join(', ')) if day_names.any?
      elsif %w[monthly yearly].include?(attrs[:frequency].to_s) && attrs[:month_option].to_s == 'day_of_week'
        parts << t('better_together.events.recurrence.summary.on_weekday_position')
      end

      case attrs[:end_type].to_s
      when 'until'
        parsed = recurrence_summary_parse_date(attrs[:ends_on])
        parts << t('better_together.events.recurrence.summary.until', date: l(parsed, format: :long)) if parsed
      when 'count'
        parts << t('better_together.events.recurrence.summary.for_count', count: attrs[:count].to_i) if attrs[:count].present?
      end

      parts.join(' ')
    end

    # Display next N occurrences
    # @param schedulable [Object] Object with RecurringSchedulable concern
    # @param count [Integer] Number of occurrences to show
    # @return [ActiveSupport::SafeBuffer] HTML safe string
    # Cancelled sessions are included (not filtered out) — a "Cancelled"
    # badge is a very different signal from the session simply not
    # appearing, which would look identical to "this date was never
    # scheduled." See RecurringSchedulable#occurrences_between.
    def next_occurrences_list(schedulable, count: 5)
      return content_tag(:p, 'Does not repeat', class: 'text-muted') unless schedulable.recurring?

      occurrences = schedulable.occurrences_between(Time.current, 1.year.from_now).take(count)

      content_tag(:ul, class: 'list-unstyled', id: 'event-upcoming-sessions') do
        occurrences.map { |occurrence| occurrence_list_item(occurrence) }.join.html_safe
      end
    end

    def occurrence_list_item(occurrence)
      content_tag(:li, id: "event-session-#{occurrence.date.iso8601}", class: 'event-session-item') do
        parts = [l(occurrence.starts_at, format: :long)]
        if occurrence.cancelled?
          parts << content_tag(:span, t('better_together.events.occurrences.cancelled_badge'),
                               class: 'badge text-bg-secondary event-session-cancelled-badge ms-2')
        end
        safe_join(parts, ' ')
      end
    end

    private

    def recurrence_summary_parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
