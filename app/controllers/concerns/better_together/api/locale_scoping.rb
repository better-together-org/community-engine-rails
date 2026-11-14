# frozen_string_literal: true

module BetterTogether
  module Api
    # API requests carry no locale of their own, but the web controllers assign I18n.locale on the serving thread
    # without restoring it, so an API write used whatever language the thread last served: the same page could get its
    # slug, title and block captions stored under es or fr one time and en the next. Each API request runs in the
    # default locale, or the one named by an X-Api-Locale header.
    module LocaleScoping
      extend ActiveSupport::Concern

      included do
        around_action :with_api_locale, prepend: true
      end

      private

      def with_api_locale(&)
        I18n.with_locale(api_locale, &)
      end

      def api_locale
        requested = request.headers['X-Api-Locale'].to_s.to_sym
        I18n.available_locales.include?(requested) ? requested : I18n.default_locale
      end
    end
  end
end
