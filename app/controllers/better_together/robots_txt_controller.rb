# frozen_string_literal: true

module BetterTogether
  # Serves a per-platform /robots.txt. The platform is resolved from the request
  # host (ApplicationController#with_current_platform_context), so every tenant
  # advertises its own sitemap on its own domain.
  #
  # NOTE: named RobotsTxtController, not RobotsController — the latter is the CRUD
  # controller for the AI-agent BetterTogether::Robot model.
  class RobotsTxtController < ApplicationController
    skip_before_action :check_platform_privacy
    skip_before_action :check_platform_setup, unless: -> { ::BetterTogether::Platform.where(host: true).any? }

    # Root-level, locale-independent paths that are never crawlable content:
    # JSON API, admin UI, signed/transient blob proxies, the bot-defense probe,
    # short-link redirects (the controller also sends X-Robots-Tag: noindex).
    ROOT_DISALLOW = %w[
      api sidekiq s bot-defense content-security rails
    ].freeze

    # Path segments under each /:locale/ that are auth / management surfaces, not
    # content. Kept deliberately short and unambiguous so a public Page slug is
    # very unlikely to collide (private controllers such as conversations already
    # emit noindex and 302 crawlers to sign-in, so they need no rule here).
    LOCALE_DISALLOW = %w[
      users host w wizards
    ].freeze

    # GET /robots.txt
    def show
      render plain: robots_body, content_type: 'text/plain'
    end

    private

    def robots_body
      return "User-agent: *\nDisallow: /\n" unless indexable_platform?

      lines = ['User-agent: *']
      lines.concat(disallow_lines)
      lines << ''
      lines.concat(sitemap_lines)
      "#{lines.join("\n")}\n"
    end

    def disallow_lines
      root = ROOT_DISALLOW.map { |seg| "Disallow: /#{seg}/" }

      segments = LOCALE_DISALLOW.dup
      # If a host keeps the default route scope ('bt'), its whole management
      # surface sits under /:locale/<scope>/ — disallow that prefix too.
      scope = BetterTogether.route_scope_path.to_s
      segments << scope if scope.present?

      localized = I18n.available_locales.flat_map do |locale|
        segments.map { |seg| "Disallow: /#{locale}/#{seg}/" }
      end
      localized << "Disallow: /#{scope}/" if scope.present?

      root + localized
    end

    def sitemap_lines
      base = current_platform.resolved_host_url.to_s.chomp('/')
      ["Sitemap: #{base}/sitemap.xml.gz"] +
        I18n.available_locales.map { |locale| "Sitemap: #{base}/#{locale}/sitemap.xml.gz" }
    end

    def indexable_platform?
      current_platform.respond_to?(:local_hosted?) &&
        current_platform.local_hosted? &&
        current_platform.privacy_public?
    end

    def current_platform
      @current_platform ||= Current.platform || helpers.host_platform
    end
  end
end
