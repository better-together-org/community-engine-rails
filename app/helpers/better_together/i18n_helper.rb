# frozen_string_literal: true

module BetterTogether
  # app/helpers/i18n_helper.rb
  module I18nHelper
    def javascript_i18n
      translations = I18n.backend.send(:translations)[I18n.locale]
      { locale: I18n.locale, translations: }
    end
  end
end
