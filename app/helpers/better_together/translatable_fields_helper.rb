# frozen_string_literal: true

module BetterTogether
  # Helpers for rendering and interacting with translatable form fields.
  # These helpers build UI elements for locale tabs, translation dropdowns
  # and translation indicators used across the admin forms.
  module TranslatableFieldsHelper # rubocop:disable Metrics/ModuleLength
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/ParameterLists
    def translatable_text_field_config(model:, scope:, temp_id:, attribute:, rows:, help_text:, input_options: {})
      resolved_temp_id = temp_id_for(model, temp_id:)
      input_options ||= {}

      default_action = 'input->better_together--translation#updateTranslationStatus'
      incoming_action = input_options.dig(:data, :action)
      combined_action = [default_action, incoming_action].compact.join(' ')

      data_attributes = {
        action: combined_action,
        'better-together-translation-target': 'input'
      }
      data_attributes.merge!(input_options[:data].except(:action)) if input_options[:data].is_a?(Hash)

      base_class = ['form-control', input_options[:class]].compact.join(' ')
      base_options = {
        rows: input_options.key?(:rows) ? input_options[:rows] : rows,
        data: data_attributes
      }.merge(input_options.except(:data, :class, :rows))

      {
        model: model,
        scope: scope,
        temp_id: resolved_temp_id,
        attribute: attribute,
        help_text: help_text,
        base_options: base_options,
        base_class: base_class,
        data_attributes: data_attributes
      }
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/ParameterLists

    def translatable_text_field_options(config, locale_attribute)
      options = config[:base_options].deep_dup
      options[:id] = "#{dom_id(config[:model])}-#{locale_attribute}"
      options[:data] = config[:data_attributes].deep_dup
      options[:class] = [
        config[:base_class],
        ('is-invalid' if config[:model].errors[locale_attribute].any?)
      ].compact.join(' ')
      options
    end

    # Helper to render a translation tab button
    def translation_tab_button(attribute:, locale:, temp_id:, model:) # rubocop:todo Metrics/MethodLength
      locale_attribute = "#{attribute}_#{locale}"
      unique_locale_attribute = "#{locale_attribute}_#{temp_id}"
      translation_present = model.public_send(locale_attribute).present?

      # Base URL for the translation path, respecting the engine configuration
      base_url = BetterTogether::Engine.routes.url_helpers.ai_translate_path(locale: I18n.locale)

      content_tag(:li, class: 'nav-item', role: 'presentation',
                       data: { attribute:, locale: },
                       'data-better_together--translation-target' => 'tab') do
        content_tag(:div, class: 'input-group') do
          tab_button(locale, unique_locale_attribute, translation_present) +
            (if ENV['OPENAI_ACCESS_TOKEN']
               render_translation_dropdown(locale, unique_locale_attribute, attribute, base_url,
                                           translation_present)
             end).to_s
        end
      end
    end

    # Generates the main tab button
    def tab_button(locale, unique_locale_attribute, translation_present) # rubocop:todo Metrics/MethodLength
      content_tag(:button,
                  id: "#{unique_locale_attribute}-tab",
                  class: ['nav-link tab-button', ('active' if locale.to_s == I18n.locale.to_s),
                          ('text-success' if translation_present)],
                  data: { bs_toggle: 'tab',
                          bs_target: "##{unique_locale_attribute}-field",
                          action: 'click->better_together--translation#syncLocaleAcrossFields',
                          locale: },
                  'data-better_together--translation-target' => 'tabButton',
                  role: 'tab',
                  type: 'button',
                  aria: { controls: "#{unique_locale_attribute}-field",
                          selected: locale.to_s == I18n.locale.to_s }) do
        (t("locales.#{locale}") + translation_indicator(translation_present)).html_safe
      end
    end

    # Combines the dropdown button and menu only if the API key is present
    def render_translation_dropdown(locale, unique_locale_attribute, attribute, base_url, translation_present)
      dropdown_button(locale, unique_locale_attribute, translation_present) +
        dropdown_menu(attribute, locale, unique_locale_attribute, base_url)
    end

    # Generates the dropdown button for additional options
    def dropdown_button(locale, unique_locale_attribute, translation_present) # rubocop:todo Metrics/MethodLength
      content_tag(:button,
                  id: "#{unique_locale_attribute}-tab",
                  class: ['nav-link dropdown-toggle dropdown-toggle-split', (if locale.to_s == I18n.locale.to_s
                                                                               'active'
                                                                             end),
                          ('text-success' if translation_present)],
                  data: { bs_toggle: 'dropdown',
                          bs_target: "##{unique_locale_attribute}-dropdown",
                          locale: },
                  type: 'button',
                  aria: { controls: "#{unique_locale_attribute}-dropdown",
                          selected: locale.to_s == I18n.locale.to_s }) do
        tag.i(class: 'fas fa-language me-2')
      end
    end

    # Generates the dropdown menu with translation options
    def dropdown_menu(_attribute, locale, unique_locale_attribute, base_url) # rubocop:todo Metrics/MethodLength
      locales = I18n.available_locales.reject { |available_locale| available_locale == locale }

      items = locales.map do |available_locale|
        content_tag(:li) do
          link_to "AI Translate from #{I18n.t("locales.#{available_locale}")}", '#ai-translate',
                  class: 'dropdown-item',
                  data: {
                    'better_together--translation-target' => 'aiTranslate',
                    action: 'click->better_together--translation#aiTranslateAttribute',
                    'field-id' => "#{unique_locale_attribute}-field",
                    'source-locale' => available_locale,
                    'target-locale' => locale,
                    'base-url' => base_url # Pass the base URL
                  }
        end
      end

      content_tag(:ul, class: 'dropdown-menu') do
        safe_join(items)
      end
    end

    # Helper to render the translation indicator
    def translation_indicator(translation_present)
      if translation_present
        tag.i(class: 'fas fa-check-circle ms-2', aria_hidden: 'true', title: 'Translation available') +
          content_tag(:span, 'Translation available', class: 'visually-hidden')
      else
        tag.i(class: 'fas fa-exclamation-circle text-muted ms-2', aria_hidden: 'true',
              title: 'No translation available') +
          content_tag(:span, 'No translation available', class: 'visually-hidden')
      end
    end
  end
end
