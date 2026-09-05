# frozen_string_literal: true

module BetterTogether
  # Serves the generated per-platform sitemap stored in Active Storage.
  #
  # The platform is resolved from the request host by
  # ApplicationController#with_current_platform_context / PlatformContextMiddleware,
  # so a request to any tenant's own domain is served that tenant's sitemap.
  class SitemapsController < ApplicationController
    # Sitemaps must stay reachable by crawlers without a session, and must not
    # bounce to the setup wizard before the host platform exists.
    skip_before_action :check_platform_privacy
    skip_before_action :check_platform_setup, unless: -> { ::BetterTogether::Platform.where(host: true).any? }

    # GET /sitemap.xml.gz (sitemap index)
    def index
      serve(BetterTogether::Sitemap.find_by(platform: current_platform, locale: 'index'))
    end

    # GET /:locale/sitemap.xml.gz (locale-specific sitemap)
    def show
      locale = validate_locale(params[:locale])
      return head :not_found unless locale

      serve(BetterTogether::Sitemap.find_by(platform: current_platform, locale: locale))
    end

    private

    def serve(sitemap)
      return head :not_found unless indexable_platform?
      return head :not_found unless sitemap&.file&.attached?

      redirect_to helpers.storage_proxy_url_for(sitemap.file)
    end

    # Only locally-hosted, publicly visible platforms get a public sitemap.
    def indexable_platform?
      current_platform.respond_to?(:local_hosted?) &&
        current_platform.local_hosted? &&
        current_platform.privacy_public?
    end

    def current_platform
      @current_platform ||= Current.platform || helpers.host_platform
    end

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
