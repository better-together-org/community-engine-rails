# frozen_string_literal: true

module BetterTogether
  # Helper methods for settings page
  # rubocop:disable Metrics/ModuleLength
  module SettingsHelper
    # Renders a self-contained preference field with individual form and change tracking
    #
    # @param person [Person] the person whose preference is being edited
    # @param field_name [Symbol] the name of the preference field
    # @param options [Hash] configuration options
    # @option options [String] :label Custom label text (defaults to I18n)
    # @option options [String] :hint Helper text below the field
    # @option options [String] :icon FontAwesome icon class
    # @option options [Symbol] :field_type Type of field (:text, :select, :time_zone, :toggle, :checkbox)
    # @option options [Hash] :field_options Additional options passed to the field helper
    #
    # @example Text field
    #   <%= preference_field(current_user.person, :locale,
    #         field_type: :select,
    #         label: 'Language',
    #         icon: 'fa-language',
    #         hint: 'Choose your preferred language') %>
    #
    # @example Toggle switch
    #   <%= preference_field(current_user.person, :notify_by_email,
    #         field_type: :toggle,
    #         label: 'Email Notifications',
    #         icon: 'fa-envelope') %>
    #
    def preference_field(person, field_name, options = {})
      field_type = options[:field_type] || :text
      label_text = options[:label] || t("activerecord.attributes.better_together/person.#{field_name}")
      hint_text = options[:hint] || t("helpers.hint.person.#{field_name}", default: '')
      icon_class = options[:icon]
      field_options = options[:field_options] || {}

      url = better_together.person_path(person, locale: I18n.locale)

      content_tag(:div, class: 'preference-field-wrapper mb-4 pb-3 border-bottom',
                        data: {
                          controller: 'better-together--preference-field',
                          better_together__preference_field_url_value: url,
                          better_together__preference_field_field_name_value: field_name
                        }) do
        concat(render_field_container(person, field_name, field_type, label_text, hint_text, icon_class, field_options))
      end
    end

    private

    # rubocop:disable Metrics/ParameterLists
    def render_field_container(person, field_name, field_type, label_text, hint_text, icon_class, field_options)
      content_tag(:div, class: 'd-flex align-items-center gap-3') do
        concat(render_field_input(person, field_name, field_type, label_text, hint_text, icon_class, field_options))
        concat(render_field_toolbar)
      end
    end

    def render_field_input(person, field_name, field_type, label_text, hint_text, icon_class, field_options)
      # rubocop:enable Metrics/ParameterLists
      content_tag(:div, class: 'flex-grow-1') do
        concat(render_field_label(label_text, field_name, icon_class))
        concat(render_field_by_type(person, field_name, field_type, field_options))
        concat(content_tag(:small, hint_text, class: 'form-text text-muted')) if hint_text.present?
      end
    end

    def render_field_label(label_text, field_name, icon_class)
      content_tag(:label, for: "person_#{field_name}", class: 'form-label fw-semibold') do
        concat(content_tag(:i, '', class: "#{icon_class} me-2", 'aria-hidden': 'true')) if icon_class
        concat(label_text)
      end
    end

    # rubocop:disable Metrics/MethodLength
    def render_field_by_type(person, field_name, field_type, field_options)
      field_value = person.send(field_name)
      base_attrs = {
        id: "person_#{field_name}",
        name: "person[#{field_name}]",
        data: {
          better_together__preference_field_target: 'field',
          action: 'change->better-together--preference-field#fieldChanged'
        }
      }

      case field_type
      when :select
        render_select_field(field_name, field_value, field_options, base_attrs)
      when :time_zone
        render_time_zone_field(field_value, base_attrs, field_options)
      when :toggle, :checkbox
        render_toggle_field(field_name, field_value, base_attrs)
      else
        render_text_field(field_value, base_attrs, field_options)
      end
    end
    # rubocop:enable Metrics/MethodLength

    def render_select_field(field_name, field_value, field_options, base_attrs)
      if field_name == :locale
        select_tag("person[#{field_name}]",
                   locale_options_for_select(field_value),
                   base_attrs.merge(class: 'form-select'))
      else
        choices = field_options[:choices] || []
        select_tag("person[#{field_name}]", options_for_select(choices, field_value),
                   base_attrs.merge(class: 'form-select'))
      end
    end

    # rubocop:disable Metrics/MethodLength
    def render_time_zone_field(field_value, base_attrs, _field_options)
      default_tz = field_value || ENV.fetch('APP_TIME_ZONE', 'America/St_Johns')

      # Get grouped timezone options (priority + continents)
      grouped_options = iana_timezone_options_with_priority

      # Build SlimSelect data attributes
      slim_select_data = {
        controller: 'better-together--slim-select',
        'better-together--slim-select-config-value': {
          search: true,
          searchPlaceholder: 'Search timezones...',
          searchHighlight: true,
          closeOnSelect: true,
          showSearch: true,
          searchingText: 'Searching...',
          searchText: 'No results',
          placeholderText: 'Select a timezone'
        }.to_json
      }

      # Merge base_attrs data with SlimSelect data
      merged_data = (base_attrs[:data] || {}).merge(slim_select_data)

      # Build complete HTML options
      html_options = base_attrs.merge(
        class: 'form-select',
        data: merged_data
      )

      select_tag(
        base_attrs[:name],
        grouped_options_for_select(grouped_options, default_tz),
        html_options
      )
    end
    # rubocop:enable Metrics/MethodLength

    def render_toggle_field(field_name, field_value, base_attrs)
      content_tag(:div, class: 'form-check form-switch') do
        concat(check_box_tag("person[#{field_name}]", '1', field_value,
                             base_attrs.merge(class: 'form-check-input', role: 'switch')))
        concat(label_tag("person_#{field_name}", '', class: 'form-check-label visually-hidden'))
      end
    end

    def render_text_field(field_value, base_attrs, field_options)
      text_field_tag("person[#{base_attrs[:name]}]", field_value,
                     base_attrs.merge(class: 'form-control').merge(field_options))
    end

    def render_field_toolbar
      content_tag(:div, class: 'd-flex align-items-center gap-2',
                        style: 'visibility: hidden;',
                        data: { better_together__preference_field_target: 'toolbar' }) do
        concat(render_save_button)
        concat(render_cancel_button)
      end
    end

    def render_save_button
      button_tag(type: 'button',
                 class: 'btn btn-sm btn-success',
                 data: {
                   better_together__preference_field_target: 'saveButton',
                   action: 'click->better-together--preference-field#save'
                 }) do
        concat(content_tag(:i, '', class: 'fa-solid fa-check me-1'))
        concat('Save')
      end
    end

    def render_cancel_button
      button_tag(type: 'button',
                 class: 'btn btn-sm btn-outline-secondary',
                 data: {
                   better_together__preference_field_target: 'cancelButton',
                   action: 'click->better-together--preference-field#cancel'
                 }) do
        concat(content_tag(:i, '', class: 'fa-solid fa-xmark me-1'))
        concat('Cancel')
      end
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
