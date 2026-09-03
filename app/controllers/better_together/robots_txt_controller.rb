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

    # GET /robots.txt
    def show
      render plain: robots_body, content_type: 'text/plain'
    end

    private

    def robots_body
      return "User-agent: *\nDisallow: /\n" unless indexable_platform?

      lines = ['User-agent: *', "Disallow: /#{BetterTogether.route_scope_path}/"]
      lines.concat(locale_disallow_lines)
      lines << ''
      lines.concat(sitemap_lines)
      "#{lines.join("\n")}\n"
    end

    def locale_disallow_lines
      I18n.available_locales.map { |locale| "Disallow: /#{locale}/#{BetterTogether.route_scope_path}/" }
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
