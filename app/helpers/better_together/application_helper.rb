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

    # Generates a canonical link tag for the current request.
    # Defaults to request.original_url but can be overridden by setting
    # `content_for(:canonical_url)` in views. When provided a relative path,
    # the host and locale are ensured by prefixing with `base_url_with_locale`.
    def canonical_link_tag
      canonical_url = if content_for?(:canonical_url)
                        content_for(:canonical_url)
                      else
                        request.original_url
                      end

      unless canonical_url.starts_with?('http://', 'https://')
        path = canonical_url.sub(%r{^/#{I18n.locale}}, '')
        canonical_url = "#{base_url_with_locale}#{path}"
      end

      tag.link(rel: 'canonical', href: canonical_url)
    end

    # Generates `<link rel="alternate" hreflang="..." href="...">` tags for
    # each locale supported by the application. These tags help search engines
    # understand language-specific versions of a page.
    def hreflang_links
      tags = I18n.available_locales.map do |locale|
        tag.link(rel: 'alternate', hreflang: locale, href: url_for(locale:, only_path: false))
      end

      safe_join(tags, "\n")
    end

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

    # Most commonly used timezones across different continents and regions
    # NOTE: These must be IANA identifiers that have corresponding Rails TimeZone entries
    # Rails uses Etc/UTC for UTC, and America/New_York covers both US Eastern and Canada Eastern (Toronto)
    # America/Los_Angeles covers both US Pacific and Canada Pacific (Vancouver)
    # Asia/Muscat is used for Abu Dhabi/Dubai
    COMMON_TIMEZONES = [
      'Etc/UTC',             # UTC (Rails uses Etc/UTC, not UTC)
      'America/New_York',    # US/Canada Eastern
      'America/Chicago',     # US Central
      'America/Denver',      # US Mountain
      'America/Los_Angeles', # US/Canada Pacific
      'America/Halifax',     # Canada Atlantic
      'America/Mexico_City', # Mexico
      'America/Sao_Paulo',   # Brazil
      'Europe/London',       # UK
      'Europe/Paris',        # France/Central Europe
      'Europe/Berlin',       # Germany
      'Europe/Amsterdam',    # Netherlands
      'Europe/Rome',         # Italy
      'Europe/Madrid',       # Spain
      'Asia/Tokyo',          # Japan
      'Asia/Shanghai',       # China
      'Asia/Hong_Kong',      # Hong Kong
      'Asia/Singapore',      # Singapore
      'Asia/Muscat',         # UAE (Abu Dhabi/Dubai)
      'Asia/Kolkata',        # India
      'Australia/Sydney',    # Australia Eastern
      'Australia/Melbourne', # Australia Eastern
      'Pacific/Auckland',    # New Zealand
      'Africa/Johannesburg'  # South Africa
    ].freeze

    # Returns timezone options sorted by UTC offset (ascending), then alphabetically
    # Display format: "(GMT-05:00) Eastern Time (US & Canada)"
    # Value is the IANA identifier: "America/New_York"
    # Returns array of [display_name, iana_identifier] pairs
    def iana_timezone_options_for_select
      # Build a hash of IANA ID => Rails TimeZone to deduplicate
      # (some IANA identifiers have multiple Rails TimeZone names like Tokyo/Osaka/Sapporo)
      zones_hash = ActiveSupport::TimeZone.all.each_with_object({}) do |rails_tz, hash|
        iana_id = rails_tz.tzinfo.name
        # Only store first Rails TimeZone for each IANA identifier
        hash[iana_id] ||= rails_tz
      end

      # Convert to array of [display_name, iana_id, offset] for sorting
      zones = zones_hash.map do |iana_id, rails_tz|
        display_name = rails_tz.to_s  # "(GMT-05:00) Eastern Time (US & Canada)"
        offset_seconds = rails_tz.utc_offset
        
        [display_name, iana_id, offset_seconds]
      end

      # Sort by offset (ascending), then alphabetically by display name, then by IANA ID
      zones.sort_by { |tz_name, tz_id, offset| [offset, tz_name, tz_id] }
           .map { |tz_name, tz_id, _offset| [tz_name, tz_id] }
    end

    # Returns commonly used timezone options sorted by UTC offset
    # Used for the "Common Timezones" priority optgroup
    def priority_timezone_options
      # Build a hash of IANA ID => Rails TimeZone to deduplicate
      # (some IANA identifiers have multiple Rails TimeZone names like Tokyo/Osaka/Sapporo)
      priority_zones_hash = ActiveSupport::TimeZone.all.each_with_object({}) do |rails_tz, hash|
        iana_id = rails_tz.tzinfo.name
        next unless COMMON_TIMEZONES.include?(iana_id)
        # Only store first Rails TimeZone for each IANA identifier
        hash[iana_id] ||= rails_tz
      end

      # Convert to array of [display_name, iana_id, offset] for sorting
      priority_zones = priority_zones_hash.map do |iana_id, rails_tz|
        display_name = rails_tz.to_s  # "(GMT-05:00) Eastern Time (US & Canada)"
        offset_seconds = rails_tz.utc_offset
        
        [display_name, iana_id, offset_seconds]
      end

      # Sort by offset (ascending), then alphabetically by display name, then by IANA ID
      priority_zones.sort_by { |tz_name, tz_id, offset| [offset, tz_name, tz_id] }
                    .map { |tz_name, tz_id, _offset| [tz_name, tz_id] }
    end

    # Returns timezone options grouped by continent/region, excluding priority zones
    # Each group is sorted by UTC offset (ascending), then alphabetically
    def iana_timezone_options_grouped
      # Build a hash of IANA ID => Rails TimeZone to deduplicate
      # (some IANA identifiers have multiple Rails TimeZone names)
      zones_hash = ActiveSupport::TimeZone.all.each_with_object({}) do |rails_tz, hash|
        iana_id = rails_tz.tzinfo.name
        next if COMMON_TIMEZONES.include?(iana_id) # Exclude priority zones
        next unless iana_id.include?('/') # Skip legacy POSIX timezone names (HST, PST8PDT, etc.)
        next if iana_id.start_with?('Etc/') # Skip technical Etc/ timezones

        # Only store first Rails TimeZone for each IANA identifier
        hash[iana_id] ||= rails_tz
      end

      # Convert to array of [continent, display_name, iana_id, offset] for grouping
      all_zones = zones_hash.map do |iana_id, rails_tz|
        display_name = rails_tz.to_s  # "(GMT-05:00) Eastern Time (US & Canada)"
        offset_seconds = rails_tz.utc_offset

        # Group by continent (first segment before /)
        continent = iana_id.split('/').first
        [continent, display_name, iana_id, offset_seconds]
      end

      # Group by continent
      grouped = all_zones.group_by { |continent, _tz_name, _tz_id, _offset| continent }

      # Sort each group by offset, then alphabetically by display name, then by IANA ID
      grouped.transform_values do |zones|
        zones.sort_by { |_continent, tz_name, tz_id, offset| [offset, tz_name, tz_id] }
             .map { |_continent, tz_name, tz_id, _offset| [tz_name, tz_id] }
      end
    end

    # Returns timezone options with priority group first, then continent-grouped options
    # Format suitable for grouped_options_for_select
    def iana_timezone_options_with_priority
      priority_group = ['Common Timezones', priority_timezone_options]
      continent_groups = iana_timezone_options_grouped.sort.to_a

      [priority_group] + continent_groups
    end

    # Renders an IANA timezone select field with SlimSelect integration
    # Uses grouped options (priority zones + continent groups) and includes
    # SlimSelect controller for enhanced search/filter UX
    #
    # Supports multiple calling patterns for backward compatibility:
    #   iana_time_zone_select(form, :timezone)
    #   iana_time_zone_select(form, :timezone, 'America/New_York')
    #   iana_time_zone_select(form, :timezone, nil, {}, html_options)
    #   iana_time_zone_select(form, :timezone, options: {}, html_options: {})
    #
    # @param form [ActionView::Helpers::FormBuilder] The form builder object
    # @param attribute [Symbol] The attribute name (e.g., :timezone)
    # @param selected_or_priority [String, Array, nil] Selected timezone or priority zones array
    # @param options [Hash] Standard Rails select options (include_blank, prompt, etc.)
    # @param html_options [Hash] HTML options for the select tag
    # @return [String] HTML select element with SlimSelect integration
    # rubocop:disable Metrics/MethodLength
    def iana_time_zone_select(form, attribute, selected_or_priority = nil, options = {}, html_options = {})
      # Determine selected timezone from various sources
      selected = if selected_or_priority.is_a?(String)
                   selected_or_priority
                 else
                   html_options.delete(:selected) || options[:selected]
                 end

      # Default HTML options with SlimSelect controller integration
      default_html_options = {
        class: 'form-select',
        data: {
          controller: 'better-together--slim-select',
          'better-together--slim-select-config-value': {
            search: true,
            searchPlaceholder: 'Search timezones...',
            searchHighlight: true,
            closeOnSelect: true,
            showSearch: true,
            searchingText: 'Searching...',
            searchText: 'No results',
            placeholderText: 'Select a timezone'
          }.to_json
        }
      }

      # Merge user-provided HTML options
      merged_html_options = default_html_options.deep_merge(html_options)

      # Use grouped_options_for_select with priority + continent groups
      grouped_options = iana_timezone_options_with_priority

      form.select(
        attribute,
        grouped_options_for_select(grouped_options, selected),
        options,
        merged_html_options
      )
    end
    # rubocop:enable Metrics/MethodLength

    def friendly_timezone_label(tz_id, offset_seconds: nil)
      rails_tz = ActiveSupport::TimeZone.all.find { |t| t.tzinfo.name == tz_id }
      rails_tz ? rails_tz.to_s : tz_id
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

    # Determines the default timezone for an event form
    # Priority: event timezone > current person timezone > platform timezone > UTC
    # Reloads person and platform to ensure fresh data in tests
    # @param event [Event] The event to determine timezone for
    # @return [String] IANA timezone identifier
    def default_timezone_for_event(event)
      event_timezone_preference(event) || person_timezone_preference || platform_timezone_preference || 'UTC'
    end

    def event_timezone_preference(event)
      return unless event.respond_to?(:timezone)

      tz = event.timezone.presence
      return tz unless event.respond_to?(:new_record?) && event.new_record?

      default_column_tz = event.class.try(:column_defaults).try(:[], 'timezone')
      return nil if tz.present? && default_column_tz.present? && tz == default_column_tz

      tz
    end

    def person_timezone_preference
      return @person_timezone_preference if defined?(@person_timezone_preference)

      person = respond_to?(:current_user) ? current_user&.person : current_person
      @person_timezone_preference = person&.time_zone.presence
    end

    def platform_timezone_preference
      return @platform_timezone_preference if defined?(@platform_timezone_preference)

      platform = host_platform || BetterTogether::Platform.find_by(host: true)
      @platform_timezone_preference = platform&.time_zone.presence
    end
  end
end
