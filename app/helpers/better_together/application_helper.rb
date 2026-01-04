# frozen_string_literal: true

module BetterTogether
  # Provides helper methods used across the BetterTogether engine.
  # These methods facilitate access to common resources like the current user,
  # platform configurations, and navigation items.
  module ApplicationHelper # rubocop:todo Metrics/ModuleLength
    include MetricsHelper

    # Returns the base URL configured for BetterTogether.
    def base_url
      ::BetterTogether.base_url
    end

    # Returns the base URL configured for BetterTogether.
    def base_url_with_locale
      ::BetterTogether.base_url_with_locale
    end

    # Returns the base path configured for BetterTogether.
    def base_path
      ::BetterTogether.base_path
    end

    # Returns the base path configured for BetterTogether plus the locale.
    def base_path_with_locale
      ::BetterTogether.base_path_with_locale
    end

    # Returns the current active identity for the user.
    # This is a placeholder and should be updated to support active identity features.
    def current_identity
      @current_identity ||= current_person
    end

    # Retrieves the current person associated with the signed-in user.
    # Returns nil if no user is signed in or the user has no associated person.
    def current_person
      return unless user_signed_in? && current_user.person

      @current_person ||= current_user.person
    end

    def default_url_options
      super.merge(locale: I18n.locale)
    end

    def permitted_to?(permission_identifier)
      return false unless current_person.present?

      current_person.permitted_to?(permission_identifier)
    end

    def help_banner_hidden?(banner_id)
      return false unless current_person.respond_to?(:preferences)

      current_person.preferences.dig('help_banners', banner_id, 'hidden') == true
    end

    # One-liner helper to render the reusable help banner
    # Usage examples:
    #   <%= help_banner id: 'joatu-offers-index', i18n_key: 'better_together.joatu.help.offers.index' %>
    #   <%= help_banner id: 'my-banner', text: 'Custom help text', image_path: 'ui/help.png' %>
    #   <%= help_banner id: 'with-icon', i18n_key: 'key', icon: 'fas fa-question-circle text-primary' %>
    def help_banner(id:, i18n_key: nil, text: nil, **)
      render('better_together/shared/help_banner', id:, i18n_key:, text:, **)
    end

    # Finds the platform marked as host or returns a new default host platform instance.
    # This method ensures there is always a host platform available, even if not set in the database.
    def host_platform
      platform = ::BetterTogether::Platform.find_by(host: true)
      return platform if platform

      ::BetterTogether::Platform.new(name: 'Better Together Community Engine', url: base_url,
                                     privacy: 'private')
    end

    # Finds the community marked as host or returns a new default host community instance.
    def host_community
      # rubocop:todo Layout/LineLength
      @host_community ||= ::BetterTogether::Community.includes(contact_detail: [:social_media_accounts]).find_by(host: true) ||
                          # rubocop:enable Layout/LineLength
                          ::BetterTogether::Community.new(name: 'Better Together')
    end

    # Returns the proxied URL for the host community logo if attached.
    def host_community_logo_url
      return unless host_community.logo.attached?

      attachment = if host_community.respond_to?(:optimized_logo)
                     host_community.optimized_logo
                   else
                     host_community.logo
                   end

      rails_storage_proxy_url(attachment)
    end

    # Sets a translated meta description for the current view. Provide the
    # translation scope without the `meta.descriptions` prefix.
    #
    #   set_meta_description('communities.show', community_name: @resource.name)
    #
    # @param scope [String] translation scope under meta.descriptions
    # @param options [Hash] interpolation values for the translation
    def set_meta_description(scope, **options)
      content_for(:meta_description, t("meta.descriptions.#{scope}", **options))
    end

    # Builds SEO-friendly meta tags for the current view. Defaults are derived
    # from translations and fall back to the Open Graph description when set.
    # rubocop:todo Metrics/MethodLength
    def seo_meta_tags # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      description = if content_for?(:meta_description)
                content_for(:meta_description) # rubocop:todo Layout/IndentationWidth
                    elsif content_for?(:og_description)
                      content_for(:og_description)
                    else
                      t('meta.default_description', platform_name: host_platform.name)
                    end

      keywords = content_for?(:meta_keywords) ? content_for(:meta_keywords) : nil

      tags = []
      tags << tag.meta(name: 'description', content: description)
      tags << tag.meta(name: 'keywords', content: keywords) if keywords.present?

      safe_join(tags, "\n")
    end
    # rubocop:enable Metrics/MethodLength

    def robots_meta_tag(content = 'index,follow')
      # Prevent indexing when debug mode is enabled
      meta_content = if stimulus_debug_enabled?
                       'noindex,nofollow'
                     elsif content_for?(:meta_robots)
                       content_for(:meta_robots)
                     else
                       content
                     end
      tag.meta(name: 'robots', content: meta_content)
    end

    # Builds Open Graph meta tags for the current view using content blocks when
    # provided. Falls back to localized defaults and the host community logo.
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    def open_graph_meta_tags # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      og_title = if content_for?(:og_title)
             content_for(:og_title) # rubocop:todo Layout/IndentationWidth
                 elsif content_for?(:page_title)
                   t('og.page.title', title: content_for(:page_title), platform_name: host_platform.name)
                 else
                   t('og.default_title', platform_name: host_platform.name)
                 end

      og_description = if content_for?(:og_description)
                         content_for(:og_description)
                       else
                         t('og.default_description', platform_name: host_platform.name)
                       end

      og_url = content_for?(:og_url) ? content_for(:og_url) : request.original_url

      og_image = content_for?(:og_image) ? content_for(:og_image) : host_community_logo_url

      tags = []
      tags << tag.meta(property: 'og:title', content: og_title)
      tags << tag.meta(property: 'og:description', content: og_description)
      tags << tag.meta(property: 'og:url', content: og_url)
      tags << tag.meta(property: 'og:image', content: og_image) if og_image.present?
      tags << tag.meta(property: 'og:site_name', content: host_platform.name)
      tags << tag.meta(property: 'og:type', content: 'website')

      safe_join(tags, "\n")
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    # Retrieves the setup wizard for hosts or raises an error if not found.
    # This is crucial for initial setup processes and should be pre-configured.
    def host_setup_wizard
      ::BetterTogether::Wizard.find_by(identifier: 'host_setup') ||
        raise(StandardError, 'Host Setup Wizard not configured. Please run rails db:seed')
    end

    # Handles missing method calls for route helpers related to BetterTogether.
    # This allows for cleaner calls to named routes without prefixing with 'better_together.'
    def method_missing(method, *args, &) # rubocop:todo Metrics/MethodLength
      if better_together_url_helper?(method)
        if args.any? && args.first.is_a?(Hash)
          args = [args.first.merge(ApplicationController.default_url_options)]
        else
          args << ApplicationController.default_url_options
        end
        BetterTogether::Engine.routes.url_helpers.public_send(method, *args, &)
      elsif main_app_url_helper?(method)
        main_app.public_send(method, *args, &)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      better_together_url_helper?(method) || main_app_url_helper?(method) || super
    end

    # Checks if a method can be responded to, especially for dynamic route helpers.
    def respond_to?(method, include_all = false) # rubocop:todo Style/OptionalBooleanParameter
      better_together_url_helper?(method) || super
    end

    # Determines if Stimulus debug mode should be enabled
    # Enable when debug param is present or session is active and not expired
    def stimulus_debug_enabled?
      return true if params[:debug] == 'true'
      return false unless session[:stimulus_debug]

      # Check if session has expired
      if session[:stimulus_debug_expires_at].present?
        session[:stimulus_debug_expires_at] > Time.current
      else
        false
      end
    end

    private

    # Checks if a method name corresponds to a missing URL or path helper for BetterTogether.
    def main_app_url_helper?(method)
      method.to_s.end_with?('_path', '_url') && main_app.respond_to?(method)
    end

    # Checks if a method name corresponds to a missing URL or path helper for BetterTogether.
    def better_together_url_helper?(method)
      method.to_s.end_with?('_path', '_url') && BetterTogether::Engine.routes.url_helpers.respond_to?(method)
    end

    # Returns the appropriate icon and color for an event based on the person's relationship to it
    def event_relationship_icon(person, event) # rubocop:todo Metrics/MethodLength
      relationship = person.event_relationship_for(event)

      case relationship
      when :created
        { icon: 'fas fa-user-edit', color: '#28a745',
          tooltip: t('better_together.events.relationship.created', default: 'Created by you') }
      when :going
        { icon: 'fas fa-check-circle', color: '#007bff',
          tooltip: t('better_together.events.relationship.going', default: 'You\'re going') }
      when :interested
        { icon: 'fas fa-heart', color: '#e91e63',
          tooltip: t('better_together.events.relationship.interested', default: 'You\'re interested') }
      else
        { icon: 'fas fa-circle', color: '#6c757d',
          tooltip: t('better_together.events.relationship.calendar', default: 'Calendar event') }
      end
    end

    # Sanitizes a URL to prevent XSS attacks by validating it's a safe URL scheme
    # @param url [String] The URL to sanitize
    # @return [String] The sanitized URL or '#' if invalid
    def sanitize_url(url)
      return '#' if url.blank?

      # Convert to string in case it's a SafeBuffer
      url_string = url.to_s.strip

      # Check if it's a valid URL with safe scheme
      begin
        uri = URI.parse(url_string)
        # Allow http, https, mailto, tel, and relative paths
        if uri.scheme.nil? || %w[http https mailto tel].include?(uri.scheme.downcase)
          url_string
        else
          '#'
        end
      rescue URI::InvalidURIError
        # If URL parsing fails, check if it's a relative path
        url_string.start_with?('/') ? url_string : '#'
      end
    end
  end
end
