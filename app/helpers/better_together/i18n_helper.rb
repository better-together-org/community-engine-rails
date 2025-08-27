# frozen_string_literal: true

module BetterTogether
  # app/helpers/i18n_helper.rb
  module I18nHelper
    # Returns only the JavaScript-needed translations to reduce payload size
    def javascript_i18n_selective
      js_translations = {
        'better_together' => {
          'device_permissions' => {
            'status' => {
              'granted' => I18n.t('better_together.device_permissions.status.granted'),
              'denied' => I18n.t('better_together.device_permissions.status.denied'),
              'unknown' => I18n.t('better_together.device_permissions.status.unknown')
            },
            'location' => {
              'denied' => I18n.t('better_together.device_permissions.location.denied'),
              'enabled' => I18n.t('better_together.device_permissions.location.enabled'),
              'unsupported' => I18n.t('better_together.device_permissions.location.unsupported')
            }
          }
        }
      }
      { locale: I18n.locale, translations: js_translations }
    end

    # Legacy method - loads all translations (performance intensive)
    # Only use when absolutely necessary
    def javascript_i18n_full
      translations = I18n.backend.send(:translations)[I18n.locale]
      { locale: I18n.locale, translations: }
    end

    # Default to selective translations
    def javascript_i18n
      javascript_i18n_selective
    end

    # Helper for embedding specific translation keys as data attributes
    # Usage: <%= translation_data_attrs('better_together.device_permissions.status.granted',
    #                                   'better_together.device_permissions.status.denied') %>
    def translation_data_attrs(*keys)
      attrs = {}
      keys.each_with_index do |key, index|
        data_key = "data-i18n-#{index}"
        attrs[data_key] = I18n.t(key)
      end
      attrs
    end

    # Helper for device permissions controller specifically
    # Generates data attributes that match the controller's getTranslation method
    def device_permissions_data_attrs
      {
        'data-i18n-granted' => I18n.t('better_together.device_permissions.status.granted'),
        'data-i18n-denied' => I18n.t('better_together.device_permissions.status.denied'),
        'data-i18n-unknown' => I18n.t('better_together.device_permissions.status.unknown'),
        'data-i18n-location-denied' => I18n.t('better_together.device_permissions.location.denied'),
        'data-i18n-location-enabled' => I18n.t('better_together.device_permissions.location.enabled'),
        'data-i18n-location-unsupported' => I18n.t('better_together.device_permissions.location.unsupported')
      }
    end
  end
end
