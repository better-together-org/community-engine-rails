# frozen_string_literal: true

module BetterTogether
  # Facilitates building forms by pulling out reusable components and logic
  module FormHelper # rubocop:todo Metrics/ModuleLength
    def class_field_required(klass, field)
      klass.validators_on(field).any? { |v| v.kind == :presence }
    end

    # rubocop:todo Metrics/MethodLength
    def label_select_field(form) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      # rubocop:todo Metrics/BlockLength
      content_tag(:div, class: 'label-select', data: { controller: 'better_together--dependent-fields' }) do
        field_label = required_label(
          form,
          :label,
          class: 'form-label'
        )

        label_select_id = dom_id(form.object, :label).split('-').first
        select_field = form.select(
          :select_label,
          form.object.class.label_options,
          { prompt: 'Select Label', required: true },
          class: 'form-select',
          id: label_select_id,
          'data-better_together--dependent-fields-target' => 'controlField'
        )

        other_text_field = content_tag(
          :div,
          class: "other-label #{dom_class(form.object, :label_text_field)}",
          data: {
            'dependent-fields-control' => label_select_id
          },
          'data-better_together--dependent-fields-target' => 'dependentField',
          "data-show-if-control_#{label_select_id}" => 'other'
        ) do
          form.text_field(
            :text_label,
            class: 'form-control mt-3',
            placeholder: t('better_together.labelable.custom-label-placeholder')
          )
        end

        field_label + select_field + other_text_field
      end
      # rubocop:enable Metrics/BlockLength
    end
    # rubocop:enable Metrics/MethodLength

    def language_select_field(form: nil, field_name: :locale, selected_locale: I18n.locale, options: {},
                              html_options: {})
      # Merge default options with the provided options
      default_options = { prompt: t('helpers.language_select.prompt') }
      merged_options = default_options.merge(options)
      selected_locale ||= I18n.locale

      # Merge default HTML options with the provided HTML options
      default_html_options = { class: 'form-select', required: true }
      merged_html_options = default_html_options.merge(html_options)

      if form
        form.select(field_name, locale_options_for_select(selected_locale), merged_options, merged_html_options)
      else
        select_tag(field_name, locale_options_for_select(selected_locale), merged_html_options.merge(merged_options))
      end
    end

    def locale_options_for_select(selected_locale = I18n.locale)
      options_for_select(
        I18n.available_locales.map { |locale| [I18n.t("locales.#{locale}", locale:), locale] },
        selected_locale
      )
    end

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/ParameterLists
    def localized_datetime_field(field:, form: nil, label_text: nil, hint_text: nil, include_time: true,
                                 selected_value: nil, generate_label: true, **options)
      # rubocop:enable Metrics/ParameterLists
      # Determine the datetime format based on the locale and whether time should be included
      include_time ? I18n.t('time.formats.datetime_picker') : I18n.t('time.formats.date_picker')

      content_tag(:div, class: 'mb-3') do
        # Add label if provided and generate_label is true
        if generate_label
          label_html = if form
                         form.label(field, label_text,
                                    class: 'form-label')
                       else
                         label_tag(field, label_text, class: 'form-label')
                       end
          concat(label_html) if label_text
        end

        # Determine the field type (form or standalone)
        if form
          concat form.datetime_field(field, { class: 'form-control', value: selected_value }.merge(options))
        else
          concat datetime_field_tag(field, selected_value, { class: 'form-control' }.merge(options))
        end

        # Add hint text if provided
        concat content_tag(:small, hint_text, class: 'form-text text-muted') if hint_text
      end
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    def privacy_field(form:, klass:, html_options: {})
      options = { class: 'form-select', required: true }
      if html_options[:class].present?
        options[:class] = "#{options[:class]} #{html_options[:class]}".strip
        html_options = html_options.except(:class)
      end
      options.merge!(html_options)

      form.select :privacy, klass.privacies.keys.map { |privacy|
        [privacy.humanize, privacy]
      }, {}, options
    end

    # rubocop:todo Metrics/MethodLength
    # Accepts an optional label_text override which, when provided, will be used
    # instead of the model's human_attribute_name for the field. This is useful
    # when the visible label needs to be different from the translated attribute
    # name (for example: participant_ids -> "Add participants").
    # rubocop:todo Metrics/PerceivedComplexity
    def required_label(form_or_object, field, label_text: nil, **options) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      # Determine if it's a form object or just an object
      if form_or_object.respond_to?(:object)
        object = form_or_object.object
        # Use provided label_text override if present, otherwise fall back to translation
        label_text ||= object.class.human_attribute_name(field)
        class_name = options.delete(:class_name)

        # Use the provided class_name for validation check if present, otherwise use the object's class
      else
        object = form_or_object
        label_text ||= object.class.human_attribute_name(field)

        # Use the provided class_name for validation check if present, otherwise use the object's class
      end

      klass = class_name ? class_name.constantize : object.class
      is_required = class_field_required(klass, field)

      # Append asterisk for required fields and attach tooltip to the asterisk
      if is_required
        tooltip_text = I18n.t('helpers.required_info', default: 'This field is required')
        # Make the asterisk keyboard-focusable and allow the tooltip to be
        # triggered by click as well as hover/focus so it works on mobile.
        asterisk = content_tag(:span, '*', class: 'required-indicator', tabindex: 0, role: 'button',
                                           data: { bs_toggle: 'tooltip', bs_trigger: 'hover focus click' },
                                           title: tooltip_text)
        label_text += " #{asterisk}"
      end

      if form_or_object.respond_to?(:label)
        form_or_object.label(field, label_text.html_safe, options)
      else
        label_tag(field, label_text.html_safe, options)
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/MethodLength

    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/AbcSize
    # rubocop:todo Metrics/ParameterLists
    def type_select_field(form:, model_class:, selected_type: nil, include_model_class: false, include_blank: true,
                          **options)
      # rubocop:enable Metrics/ParameterLists
      # Determine if the model is persisted
      disabled = form&.object&.persisted? || false

      options = {
        required: true,
        class: 'form-select',
        data: { controller: 'better_together--slim-select' },
        disabled:, # Disable if the model is persisted
        **options
      }

      descendants = model_class.descendants.map { |descendant| [descendant.model_name.human, descendant.name] }

      dropdown_values = if include_model_class
                          [[model_class.model_name.human, model_class.name]] + descendants
                        else
                          descendants
                        end

      if form
        form.select :type, options_for_select(dropdown_values, form.object.type), { include_blank: }, options
      else
        select_tag 'type', options_for_select(dropdown_values, selected_type),
                   { include_blank: }.merge(options)
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/MethodLength

    # Generates a role selection field for invitations
    # @param form [ActionView::Helpers::FormBuilder] The form builder instance
    # @param field_name [Symbol] The name of the field (typically :role_id)
    # @param resource_type [String] The resource type to filter roles by (e.g., 'BetterTogether::Community')
    # @param prompt [String, nil] The prompt text for the select field
    # @param html_options [Hash] Additional HTML options for the select field
    # @return [String] HTML for the role selection field
    def role_select_field(form:, field_name:, resource_type:, html_options: {})
      roles = BetterTogether::Role.where(resource_type: resource_type).order(:position).i18n
      html_opts = { class: 'form-select', name: "invitation[#{field_name}]" }.merge(html_options)

      form.collection_select(field_name, roles, :id, :name, {}, html_opts)
    end
  end
end
