# frozen_string_literal: true

module BetterTogether
  # Serves the generated sitemap stored in Active Storage
  class SitemapsController < ApplicationController
    # GET /sitemap.xml.gz (sitemap index)
    def index
      sitemap = Sitemap.current_index(helpers.host_platform)
      if sitemap&.file&.attached?
        redirect_to sitemap.file.url, allow_other_host: true
      else
        head :not_found
      end
    end

    # GET /:locale/sitemap.xml.gz (locale-specific sitemap)
    def show
      locale = validate_locale(params[:locale])
      return head :not_found unless locale

      sitemap = Sitemap.current(helpers.host_platform, locale)
      if sitemap&.file&.attached?
        redirect_to sitemap.file.url, allow_other_host: true
      else
        head :not_found
      end
    end

    private

    # Validate that the requested locale is available
    # @param locale [String] The locale parameter from the request
    # @return [String, nil] The validated locale string, or nil if invalid
    def validate_locale(locale)
      return nil unless locale.present?
      return locale.to_s if I18n.available_locales.map(&:to_s).include?(locale.to_s)

      nil
    end
  end
end
