# frozen_string_literal: true

module BetterTogether
  # Provides helper methods used across the BetterTogether engine.
  # These methods facilitate access to common resources like the current user,
  # platform configurations, and navigation items.
  module ApplicationHelper # rubocop:todo Metrics/ModuleLength
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
      byebug
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

    # Finds the platform marked as host or returns a new default host platform instance.
    # This method ensures there is always a host platform available, even if not set in the database.
    def host_platform
      @host_platform ||= ::BetterTogether::Platform.find_by(host: true) ||
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
      @host_setup_wizard ||= ::BetterTogether::Wizard.find_by(identifier: 'host_setup') ||
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

    private

    # Checks if a method name corresponds to a missing URL or path helper for BetterTogether.
    def main_app_url_helper?(method)
      method.to_s.end_with?('_path', '_url') && main_app.respond_to?(method)
    end

    # Checks if a method name corresponds to a missing URL or path helper for BetterTogether.
    def better_together_url_helper?(method)
      method.to_s.end_with?('_path', '_url') && BetterTogether::Engine.routes.url_helpers.respond_to?(method)
    end
  end
end
