module BetterTogether
  # Includes support for Devise I18n
  # https://github.com/tigrish/devise-i18n?tab=readme-ov-file#setting-your-locale
  module DeviseLocales
    extend ActiveSupport::Concern

    included do
      before_action :set_locale
    end

    def set_locale
      I18n.locale = params[:locale]
    end
  end
end
