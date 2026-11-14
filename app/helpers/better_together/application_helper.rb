# frozen_string_literal: true

module BetterTogether
  # Provides helper methods used across the BetterTogether engine.
  # These methods facilitate access to common resources like the current user,
  # platform configurations, and navigation items.
  module ApplicationHelper # rubocop:todo Metrics/ModuleLength
    include MetricsHelper
    include StructuredDataHelper

    # Returns the page title for the current page, combining any page-specific title with the platform name
    def page_title(title = nil)
      title_parts = []
      title_parts << title if title.present?
      title_parts << host_platform.name if host_platform.present? && !turbo_native_app?
      title_parts.compact.join(' | ')
    end

    # Returns the base URL configured for BetterTogether.
    def base_url
      current_platform_base_url
    end

    # Returns the base URL configured for BetterTogether.
    def base_url_with_locale
      build_url_for_path(base_url, "/#{I18n.locale}")
    end

    # rubocop:disable Style/ArgumentsForwarding
    def storage_proxy_url_for(attachment, **options)
      return unless attachment.present?

      media_url_options = default_url_options.except(:locale, 'locale')
      request_base_url = request&.base_url

      url_builder_options = {
        url_options: media_url_options,
        **options
      }
      url_builder_options[:base_url] = request_base_url if request_base_url.present?

      BetterTogether::MediaUrlBuilder.proxy_url_for(
        attachment,
        **url_builder_options
      )
    end
    # rubocop:enable Style/ArgumentsForwarding

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
      @current_identity ||= current_person || (respond_to?(:current_robot) ? current_robot : nil)
    end

    # Retrieves the current person associated with the signed-in user.
    # Returns nil if no user is signed in or the user has no associated person.
    def current_person
      return unless user_signed_in? && current_user.person

      @current_person ||= current_user.person
    end

    # Path to the signed-in person's own profile. Falls back to the id when the person has no
    # slug in the current locale, so one missing slug translation cannot break every page's nav.
    def current_person_profile_path
      person_my_profile_path(person_id: current_person.slug.presence || current_person.id)
    end

    # current_user/user_signed_in? need Warden, which isn't present in two render
    # contexts this engine actually uses: Comment/Message's broadcast_append_later_to
    # (a bare renderer, no request/session) and Devise-less view/helper specs. Every
    # helper that needed to tolerate that used to add its own
    # `rescue Devise::MissingWarden` — ContentActionsHelper, CommentsHelper,
    # PeopleHelper, and this method's own former version all duplicated it
    # independently. Centralized here so call sites just use the safe accessor and
    # never need their own rescue for this specific case.
    def safe_current_user
      return nil unless respond_to?(:user_signed_in?)

      current_user if user_signed_in?
    rescue Devise::MissingWarden
      nil
    end

    def safe_current_person
      return nil unless respond_to?(:user_signed_in?)

      current_person
    rescue Devise::MissingWarden
      nil
    end

    # Generates a short-lived, signed token proving the client actually rendered a page
    # from this app recently, embedded via a <meta> tag and attached by JS
    # (trix-extensions/richtext.js) to every ActiveStorage direct-upload request. Raises
    # the bar above bare CSRF (which only proves *some* page was rendered, not
    # specifically an upload-capable one) without requiring authentication, since this
    # endpoint is used from pre-auth pages (sign-up, host-setup wizard) by design.
    def direct_upload_authorization_token
      Rails.application.message_verifier(:direct_upload).generate(
        { path: request.path, iat: Time.current.to_i }, expires_in: 30.minutes
      )
    rescue StandardError
      nil
    end

    def default_url_options
      super.merge(resolved_url_options).merge(locale: I18n.locale)
    end

    def permitted_to?(permission_identifier)
      return false unless current_person.present?

      current_person.permitted_to?(permission_identifier)
    end

    def feature_enabled?(feature_key, actor: current_person || current_robot, platform: Current.platform, record: nil)
      BetterTogether::FeatureGate.enabled?(feature_key, actor:, platform:, record:)
    rescue KeyError
      false
    end

    def contributor_display_visible_for?(record)
      return false unless record.respond_to?(:contributors_display_visible?)

      record.contributors_display_visible?
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

    def agreement_lifecycle_badge_class(agreement)
      return 'bg-secondary' unless agreement.respond_to?(:lifecycle_state)

      case agreement.lifecycle_state
      when 'draft' then 'bg-warning text-dark'
      when 'retired' then 'bg-secondary'
      else 'bg-success'
      end
    end

    def agreement_acceptance_badge_class(agreement_participant)
      return 'bg-secondary' unless agreement_participant.present?
      return 'bg-warning text-dark' if agreement_participant.stale_for_agreement?

      'bg-success'
    end

    def agreement_acceptance_state_label(agreement_participant)
      return 'Pending' unless agreement_participant.present?
      return 'Needs review' if agreement_participant.stale_for_agreement?

      'Accepted'
    end

    # Finds the platform marked as host or returns a new default host platform instance.
    # Memoized per-request to avoid repeated DB lookups (called by check_platform_setup,
    # check_platform_privacy, SEO helpers, and layout partials on every request).
    # Theme custom properties for the current platform, rendered before the platform Css block.
    def platform_theme_style_tag(platform = host_platform)
      return unless platform.respond_to?(:theme_config)

      banner = storage_proxy_url_for(platform.header_banner) if platform.header_banner.attached?
      css = platform.theme_config.to_css(banner_url: banner)
      content_tag(:style, css.html_safe, type: 'text/css', id: 'platform-theme-style') if css.present? # rubocop:disable Rails/OutputSafety
    end

    COLOR_MODE_COOKIE = 'bts_color_mode'

    # The signed-in person, when the helper is rendered where authentication exists.
    def theme_person
      safe_current_person
    end

    # The theme id the signed-in person chose, when the platform allows personal themes and the id is
    # still in the registry. Blank means "use the platform's theme".
    def user_theme_id(platform = host_platform)
      id = theme_person&.theme.presence
      return unless id && platform.respond_to?(:allow_user_themes?) && platform.allow_user_themes?

      id if BetterTogether::PlatformThemeConfig.themes.key?(id)
    end

    # The colour mode the signed-in person chose (never gated by allow_user_themes), or nil.
    def user_color_mode
      mode = theme_person&.color_mode
      mode if BetterTogether::PlatformThemeConfig::COLOR_MODES.include?(mode)
    end

    # Whether visitors can switch colour modes: the platform theme allows it, or the person chose a mode.
    def color_mode_enabled?(platform = host_platform)
      (platform.respond_to?(:theme_config) && platform.theme_config.dark_mode_enabled?) || user_color_mode.present?
    end

    # The saved mode: the signed-in person's stored choice, else the visitor's cookie, else the platform
    # default (auto, light or dark).
    def color_mode_preference(platform = host_platform)
      return user_color_mode if user_color_mode

      saved = cookies[COLOR_MODE_COOKIE]
      return saved if BetterTogether::PlatformThemeConfig::COLOR_MODES.include?(saved)

      platform.respond_to?(:theme_config) ? platform.theme_config.default_mode : 'auto'
    end

    # Attributes for the html element. An explicit light or dark mode is rendered server side so the
    # first paint is right; auto is resolved by the inline head script from prefers-color-scheme.
    def html_color_mode_attributes(platform = host_platform)
      return {} unless color_mode_enabled?(platform)

      mode = color_mode_preference(platform)
      attrs = { 'data-bts-color-mode' => mode }
      attrs['data-bs-theme'] = mode unless mode == 'auto'
      attrs['data-bts-user-mode'] = user_color_mode if user_color_mode
      attrs['data-bts-user-theme'] = user_theme_id(platform) if user_theme_id(platform)
      attrs
    end

    # The signed-in person's own theme, rendered after the platform theme and before the platform Css block.
    # Anonymous visitors, and people on platforms that disallow personal themes, get nothing.
    def user_theme_style_tag(platform = host_platform)
      css = user_theme_css(platform)
      content_tag(:style, css.html_safe, type: 'text/css', id: 'user-theme-style') if css.present? # rubocop:disable Rails/OutputSafety
    end

    def user_theme_css(platform = host_platform)
      return unless platform.respond_to?(:theme_config)

      platform_dark = platform.theme_config.dark_mode_enabled?
      if (id = user_theme_id(platform))
        BetterTogether::PlatformThemeConfig.user_css(id, dark_mode_enabled: platform_dark || user_color_mode.present?)
      elsif user_color_mode.present? && !platform_dark
        # The platform turned dark mode off, but this person chose a mode: give them dark tokens too.
        BetterTogether::PlatformThemeConfig.new(platform.theme_config.values.merge('dark_mode' => 'enabled')).to_css
      end
    end

    def color_scheme_meta_tag(platform = host_platform)
      tag.meta name: 'color-scheme', content: color_mode_enabled?(platform) ? 'light dark' : 'light'
    end

    # Runs before first paint: resolves the saved or default mode to data-bs-theme. For a signed-in person
    # the stored choice (data-bts-user-mode) wins and is mirrored into localStorage and the cookie.
    def color_mode_head_script_tag(platform = host_platform)
      return unless color_mode_enabled?(platform)

      javascript_tag(<<~JS.squish, nonce: true)
        (function(){try{var d=document.documentElement,m=d.getAttribute('data-bts-color-mode')||'auto',u=d.getAttribute('data-bts-user-mode');
        if(u==='auto'||u==='light'||u==='dark'){m=u;
        try{localStorage.setItem('bts-color-mode',u);}catch(e){}
        document.cookie='bts_color_mode='+u+'; path=/; max-age=31536000; SameSite=Lax'+(location.protocol==='https:'?'; Secure':'');}
        else{try{var s=localStorage.getItem('bts-color-mode');if(s==='auto'||s==='light'||s==='dark'){m=s;}}catch(e){}}
        var t=m==='auto'?(window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light'):m;
        d.setAttribute('data-bs-theme',t);d.setAttribute('data-bts-color-mode',m);}catch(e){}})();
      JS
    end

    def platform_favicon_tag(platform = host_platform)
      return unless platform.respond_to?(:favicon) && platform.favicon.attached?

      tag.link(rel: 'icon', href: storage_proxy_url_for(platform.favicon), type: platform.favicon.content_type)
    end

    def host_platform
      @host_platform ||= Current.platform || ::BetterTogether::Platform.find_by(host: true) ||
                         ::BetterTogether::Platform.new(
                           name: 'Better Together Community Engine',
                           url: ::BetterTogether.base_url,
                           privacy: 'private'
                         )
    end

    # Finds the community marked as host or returns a new default host community instance.
    def host_community
      @host_community ||= host_platform.community ||
                          # rubocop:todo Layout/LineLength
                          ::BetterTogether::Community.includes(contact_detail: [:social_media_accounts]).find_by(host: true) ||
                          # rubocop:enable Layout/LineLength
                          ::BetterTogether::Community.new(name: 'Better Together')
    end

    # Returns the preferred public email for the host community, if any.
    def host_community_primary_email
      contact_detail = host_community.contact_detail
      return unless contact_detail

      public_emails = contact_detail.email_addresses.privacy_public.to_a
      primary = public_emails.find(&:primary_flag?)

      primary&.email || public_emails.first&.email
    end

    # Returns the proxied URL for the host community logo if attached.
    def host_community_logo_url
      return unless host_community.logo.attached?

      attachment = if host_community.respond_to?(:optimized_logo)
                     host_community.optimized_logo
                   else
                     host_community.logo
                   end

      storage_proxy_url_for(attachment)
    end

    # Sets a translated meta description for the current view. Provide the
    # translation scope without the `meta.descriptions` prefix.
    #
    #   set_meta_description('communities.show', community_name: @resource.name)
    #
    # @param scope [String] translation scope under meta.descriptions
    # @param options [Hash] interpolation values for the translation
    def set_meta_description(scope, **)
      content_for(:meta_description, t("meta.descriptions.#{scope}", **))
    end

    # Builds SEO-friendly meta tags for the current view. Defaults are derived
    # from translations and fall back to the Open Graph description when set.
    # rubocop:todo Metrics/MethodLength
    def seo_meta_tags # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      description = if content_for?(:meta_description)
                      meta_content_for(:meta_description)
                    elsif content_for?(:og_description)
                      meta_content_for(:og_description)
                    else
                      t('meta.default_description', platform_name: host_platform.name)
                    end

      keywords = content_for?(:meta_keywords) ? meta_content_for(:meta_keywords) : nil

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

    # True when this page may be measured by third-party vendors. Vendor extensions must check it
    # before emitting scripts. Controllers outside the engine's base class are treated as allowed.
    def third_party_tracking_allowed?
      return true unless controller.respond_to?(:third_party_tracking_allowed?, true)

      controller.send(:third_party_tracking_allowed?)
    end

    # Lets vendor scripts that stay loaded across Turbo visits learn what the current page allows.
    def third_party_tracking_meta_tag
      tag.meta(name: 'bt-third-party-tracking', content: third_party_tracking_allowed? ? 'on' : 'off')
    end

    def render_provider_head_tags
      fragments = ::BetterTogether.head_tag_providers.values.filter_map do |provider|
        fragment = provider.call(self)
        fragment.presence
      end

      safe_join(fragments, "\n")
    end

    OG_TYPES = %w[website article profile book].freeze

    # Reads a content_for value as single-line text. Views capture ERB blocks,
    # so the raw value carries the indentation and newlines around the content.
    def meta_content_for(name)
      content_for(name).to_s.squish
    end

    # Open Graph type for the page. Views may set `content_for :og_type` to one
    # of OG_TYPES; anything else falls back to "website".
    def og_type
      requested = content_for?(:og_type) ? meta_content_for(:og_type) : nil
      OG_TYPES.include?(requested) ? requested : 'website'
    end

    # Absolute share-image URL: a view-provided image, else the host community logo.
    def og_image_url
      url = content_for?(:og_image) ? meta_content_for(:og_image) : host_community_logo_url
      return url if url.blank? || url.start_with?('http://', 'https://')

      "#{request.base_url}/#{url.delete_prefix('/')}"
    end

    # og:image plus width, height and alt when views provide them
    # (`content_for :og_image_width`, `:og_image_height`, `:og_image_alt`).
    def og_image_meta_tags(image_url)
      tags = [tag.meta(property: 'og:image', content: image_url)]
      { width: :og_image_width, height: :og_image_height, alt: :og_image_alt }.each do |suffix, key|
        value = content_for?(key) ? meta_content_for(key) : nil
        tags << tag.meta(property: "og:image:#{suffix}", content: value) if value.present?
      end
      tags
    end

    # Width and height recorded in an attachment blob's metadata, as the
    # content_for-ready strings used by og_image_meta_tags.
    def og_image_dimensions(attachment)
      metadata = attachment.blob&.metadata || {}
      { width: metadata['width'], height: metadata['height'] }.compact_blank.transform_values(&:to_s)
    end

    # Builds Open Graph meta tags for the current view using content blocks when
    # provided. Falls back to localized defaults and the host community logo.
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    def open_graph_meta_tags # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      og_title = if content_for?(:og_title)
                   meta_content_for(:og_title)
                 elsif content_for?(:page_title)
                   t('og.page.title', title: meta_content_for(:page_title), platform_name: host_platform.name)
                 else
                   t('og.default_title', platform_name: host_platform.name)
                 end

      og_description = if content_for?(:og_description)
                         meta_content_for(:og_description)
                       else
                         t('og.default_description', platform_name: host_platform.name)
                       end

      og_url = content_for?(:og_url) ? canonicalize_url(meta_content_for(:og_url)) : canonical_current_url

      og_image = og_image_url

      tags = []
      tags << tag.meta(property: 'og:title', content: og_title)
      tags << tag.meta(property: 'og:description', content: og_description)
      tags << tag.meta(property: 'og:url', content: og_url)
      tags.concat(og_image_meta_tags(og_image)) if og_image.present?
      tags << tag.meta(property: 'og:site_name', content: host_platform.name)
      tags << tag.meta(property: 'og:type', content: og_type)

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
                        explicit_or_canonical_url(meta_content_for(:canonical_url))
                      else
                        canonical_current_url
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
        url_options_with_locale = engine_url_options_with_locale
        if args.any? && args.first.is_a?(Hash)
          args = [args.first.merge(url_options_with_locale)]
        else
          args << url_options_with_locale
        end
        BetterTogether::Engine.routes.url_helpers.public_send(method, *args, &)
      elsif main_app_url_helper?(method)
        main_app.public_send(method, *args, &)
      else
        super
      end
    end

    # In host-app controllers the view class's own default_url_options (from the
    # main app routes) can shadow this module's, dropping :locale. Engine routes
    # are /:locale/..., so a record passed positionally would then be read as the locale.
    def engine_url_options_with_locale
      default_url_options.reverse_merge(locale: I18n.locale)
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

    def current_platform_domain
      Current.platform_domain ||
        Current.platform&.primary_platform_domain ||
        ::BetterTogether::Platform.find_by(host: true)&.primary_platform_domain
    end

    def canonical_current_url
      canonicalize_url(request.original_url)
    end

    def canonicalize_url(url)
      return url if url.blank?

      url = url.to_s.strip
      uri = URI.parse(url)
      path = extract_canonical_path(uri, url)
      build_url_for_path(base_url, path) + uri_query_string(uri) + uri_fragment_string(uri)
    rescue URI::InvalidURIError
      build_url_for_path(base_url_with_locale, normalize_relative_path(url))
    end

    def uri_query_string(uri)
      uri.query.present? ? "?#{uri.query}" : ''
    end

    def uri_fragment_string(uri)
      uri.fragment.present? ? "##{uri.fragment}" : ''
    end

    def extract_canonical_path(uri, _original_url)
      if uri.host.present?
        uri.path.presence || '/'
      else
        normalize_relative_path(uri.path.presence || '/')
      end
    end

    def explicit_or_canonical_url(url)
      return url if url.to_s.start_with?('http://', 'https://')

      canonicalize_url(url)
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
    # rubocop:disable Metrics/AbcSize
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
        display_name = rails_tz.to_s # "(GMT-05:00) Eastern Time (US & Canada)"
        offset_seconds = rails_tz.utc_offset

        [display_name, iana_id, offset_seconds]
      end

      # Sort by offset (ascending), then alphabetically by display name, then by IANA ID
      zones.sort_by { |tz_name, tz_id, offset| [offset, tz_name, tz_id] }
           .map { |tz_name, tz_id, _offset| [tz_name, tz_id] }
    end
    # rubocop:enable Metrics/AbcSize

    # Returns commonly used timezone options sorted by UTC offset
    # Used for the "Common Timezones" priority optgroup
    # rubocop:disable Metrics/AbcSize
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
        display_name = rails_tz.to_s # "(GMT-05:00) Eastern Time (US & Canada)"
        offset_seconds = rails_tz.utc_offset

        [display_name, iana_id, offset_seconds]
      end

      # Sort by offset (ascending), then alphabetically by display name, then by IANA ID
      priority_zones.sort_by { |tz_name, tz_id, offset| [offset, tz_name, tz_id] }
                    .map { |tz_name, tz_id, _offset| [tz_name, tz_id] }
    end
    # rubocop:enable Metrics/AbcSize

    # Returns timezone options grouped by continent/region, excluding priority zones
    # Each group is sorted by UTC offset (ascending), then alphabetically
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    # rubocop:disable Metrics/PerceivedComplexity
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
        display_name = rails_tz.to_s # "(GMT-05:00) Eastern Time (US & Canada)"
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
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

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

    def friendly_timezone_label(tz_id)
      rails_tz = ActiveSupport::TimeZone.all.find { |t| t.tzinfo.name == tz_id }
      rails_tz ? rails_tz.to_s : tz_id
    end

    private

    def current_platform_base_url
      Current.platform&.resolved_host_url ||
        current_platform_domain&.url ||
        ::BetterTogether::Platform.find_by(host: true)&.resolved_host_url ||
        ::BetterTogether.base_url
    end

    def build_url_for_path(root_url, path)
      root = root_url.to_s.chomp('/')
      normalized_path = normalize_relative_path(path)
      "#{root}#{normalized_path}"
    end

    def normalize_relative_path(path)
      normalized = path.to_s
      normalized = "/#{normalized}" unless normalized.start_with?('/')
      normalized
    end

    def resolved_url_options
      uri = URI.parse(base_url)
      options = { host: uri.host }
      options[:protocol] = uri.scheme if uri.scheme.present?
      options[:port] = uri.port if uri.port.present? && ![80, 443].include?(uri.port)
      options
    end

    # Checks if a method name corresponds to a missing URL or path helper for BetterTogether.
    def main_app_url_helper?(method)
      method.to_s.end_with?('_path', '_url') && main_app.respond_to?(method)
    end

    # Checks if a method name corresponds to a missing URL or path helper for BetterTogether.
    def better_together_url_helper?(method)
      method.to_s.end_with?('_path', '_url') && BetterTogether::Engine.routes.url_helpers.respond_to?(method)
    end

    def turbo_native_app?
      request.user_agent.to_s.include?('Turbo Native')
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

      @platform_timezone_preference = host_platform&.time_zone.presence
    end
  end
end
