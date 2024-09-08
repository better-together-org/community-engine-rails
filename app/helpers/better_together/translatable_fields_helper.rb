
module BetterTogether
  module TranslatableFieldsHelper
    # Helper to render a translation tab button
    def translation_tab_button(attribute:, locale:, temp_id:, model:)
      locale_attribute = "#{attribute}_#{locale}"
      unique_locale_attribute = "#{locale_attribute}_#{temp_id}"
      translation_present = model.public_send(locale_attribute).present?
    
      content_tag(:li, class: 'nav-item', role: 'presentation',
                  data: { attribute: attribute, translation_target: 'tab', locale: locale }) do
        content_tag(:button,
                    id: "#{unique_locale_attribute}-tab",
                    class: ['nav-link', ('active' if locale.to_s == I18n.locale.to_s), 
                            ('text-success' if translation_present)],
                    data: { bs_toggle: 'tab',
                            bs_target: "##{unique_locale_attribute}-field",
                            action: 'click->translation#syncLocaleAcrossFields',
                            locale: locale,
                            translation_target: 'tabButton' },
                    role: 'tab',
                    type: 'button',
                    aria: { controls: "#{unique_locale_attribute}-field",
                            selected: locale.to_s == I18n.locale.to_s }) do
          (t("locales.#{locale}") + translation_indicator(translation_present)).html_safe
        end
      end
    end

    # Helper to render the translation indicator
    def translation_indicator(translation_present)
      if translation_present
        tag.i(class: 'fas fa-check-circle ms-2', aria_hidden: 'true', title: 'Translation available') +
          content_tag(:span, 'Translation available', class: 'visually-hidden')
      else
        tag.i(class: 'fas fa-exclamation-circle text-muted ms-2', aria_hidden: 'true', title: 'No translation available') +
          content_tag(:span, 'No translation available', class: 'visually-hidden')
      end
    end
  end
end