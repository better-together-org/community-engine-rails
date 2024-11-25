module BetterTogether
  # Facilitates building forms by pulling out reusable components and logic
  module FormHelper
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

    def localized_datetime_field(field:, form: nil, label_text: nil, hint_text: nil, include_time: true,
                                 selected_value: nil, generate_label: true, **options)
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

    def privacy_field(form:, klass:)
      form.select :privacy, klass.privacies.keys.map { |privacy|
        [privacy.humanize, privacy]
      }, {}, { class: 'form-select', required: true }
    end

    def required_label(form_or_object, field, **options)
      # Determine if it's a form object or just an object
      if form_or_object.respond_to?(:object)
        object = form_or_object.object
        label_text = object.class.human_attribute_name(field)
        class_name = options.delete(:class_name)

        # Use the provided class_name for validation check if present, otherwise use the object's class
        klass = class_name ? class_name.constantize : object.class
        is_required = klass.validators_on(field).any? { |v| v.kind == :presence }
      else
        object = form_or_object
        label_text = object.class.human_attribute_name(field)

        # Use the provided class_name for validation check if present, otherwise use the object's class
        klass = class_name ? class_name.constantize : object.class
        is_required = klass.validators_on(field).any? { |v| v.kind == :presence }
      end

      # Append asterisk for required fields
      label_text += " <span class='required-indicator'>*</span>" if is_required

      if form_or_object.respond_to?(:label)
        form_or_object.label(field, label_text.html_safe, options)
      else
        label_tag(field, label_text.html_safe, options)
      end
    end

    def type_select_field(form:, model_class:, selected_type: nil, include_blank: true, **options)
      # Determine if the model is persisted
      disabled = form&.object&.persisted? || false

      options = {
        **options,
        required: true,
        class: 'form-select',
        disabled: disabled # Disable if the model is persisted
      }

      descendants = model_class.descendants.map { |descendant| [descendant.model_name.human, descendant.name] }

      if form
        form.select :type, options_for_select(descendants, form.object.type), { include_blank: include_blank }, options
      else
        select_tag 'type', options_for_select(descendants, selected_type),
                   { include_blank: include_blank }.merge(options)
      end
    end
  end
end
