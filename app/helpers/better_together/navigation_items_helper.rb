# frozen_string_literal: true

module BetterTogether
  # rubocop:todo Metrics/ModuleLength
  module NavigationItemsHelper # rubocop:todo Style/Documentation, Metrics/ModuleLength
    def better_together_nav_area
  # rubocop:todo Layout/IndentationWidth
  @better_together_nav_area ||= ::BetterTogether::NavigationArea.visible.find_by(identifier: 'better-together')
      # rubocop:enable Layout/IndentationWidth
    end

    # Retrieves navigation items for the BetterTogether header navigation.
    def better_together_nav_items
      # Preload navigation items and their translations in a single query
      Mobility.with_locale(current_locale) do
        @better_together_nav_items ||= @better_together_nav_area.top_level_nav_items_includes_children || []
      end
    end

    def render_better_together_nav_items
      return unless better_together_nav_area

      Rails.cache.fetch(cache_key_for_nav_area(better_together_nav_area)) do
        render 'better_together/navigation_items/navigation_items', navigation_items: better_together_nav_items
      end
    end

    def cache_key_for_nav_area(nav)
      [
        'nav_area_items',
        nav.cache_key_with_version, # Ensure cache expires when nav updates
        current_user&.cache_key_with_version
      ].compact # removes nil values for unauthenticated users
    end

    def dropdown_id(navigation_item)
      dom_id(navigation_item, navigation_item.slug)
    end

    def dropdown_role(navigation_item)
      navigation_item.children? ? 'button' : nil
    end

    def dropdown_data_attributes(navigation_item)
      data = { 'identifier' => navigation_item.identifier }
      if navigation_item.children?
        data = data.merge({ 'bs-toggle' => 'dropdown', 'aria-expanded' => 'false',
                            'bs-target' => "##{dom_id(navigation_item, navigation_item.slug)}" })
      end

      data
    end

    def nav_link_classes(navigation_item, path: nil)
      classes = dom_class(navigation_item, navigation_item.slug)
      classes += ' nav-link text-center'
      classes += ' dropdown-toggle' if navigation_item.children?
      classes += ' active' if nav_link_active?(navigation_item, path:)
      classes
    end

    def platform_host_nav_area
      @platform_host_nav_area ||= ::BetterTogether::NavigationArea.visible.find_by(identifier: 'platform-host')
    end

    # Retrieves navigation items for the admin area in the platform header.
    def platform_host_nav_items
      return [] unless platform_host_nav_area

      # Preload navigation items and their translations in a single query
      Mobility.with_locale(current_locale) do
        @platform_host_nav_items ||= platform_host_nav_area.top_level_nav_items_includes_children || []
      end
    end

    def render_platform_host_nav_items
      return unless platform_host_nav_area

      Rails.cache.fetch(cache_key_for_nav_area(platform_host_nav_area)) do
        render 'better_together/navigation_items/navigation_items',
               navigation_items: platform_host_nav_items,
               navigation_area: platform_host_nav_area
      end
    end

    def platform_host_nav_visible?
      return false unless current_user

      platform_host_nav_items.any? { |item| navigation_item_visible_for?(item, platform: host_platform) }
    end

    def navigation_item_visible_for?(navigation_item, platform: host_platform)
      return true if navigation_item.visible_to?(current_user, platform: platform)

      navigation_item.dropdown? &&
        navigation_item.children.any? { |child| child.visible_to?(current_user, platform: platform) }
    end

    def navigation_item_children_for(navigation_item, platform: host_platform)
      navigation_item.children.select { |child| child.visible_to?(current_user, platform: platform) }
    end

    def platform_host_nav_children
      return [] unless platform_host_nav_area

      host_nav = platform_host_nav_item
      return [] unless host_nav

      children = host_nav.children.visible
      children.select { |child| child.visible_to?(current_user, platform: host_platform) }
    end

    def render_platform_host_sidebar_nav
      host_nav_items = platform_host_nav_children
      return if host_nav_items.blank?

      render 'layouts/better_together/host_sidebar_nav', host_nav_items: host_nav_items
    end

    def platform_footer_nav_area
      @platform_footer_nav_area ||= ::BetterTogether::NavigationArea.visible.find_by(identifier: 'platform-footer')
    end

    # Retrieves navigation items for the mailer footer.
    def mailer_footer_nav_items
      # Preload navigation items and their translations in a single query
      Mobility.with_locale(current_locale) do
        @mailer_footer_nav_items ||=
          platform_footer_nav_area&.top_level_nav_items_includes_children&.excluding_hashed || []
      end
    end

    # Retrieves navigation items for the platform footer.
    def platform_footer_nav_items
      # Preload navigation items and their translations in a single query
      Mobility.with_locale(current_locale) do
        @platform_footer_nav_items ||= platform_footer_nav_area&.top_level_nav_items_includes_children || []
      end
    end

    def render_platform_footer_nav_items
      return unless platform_footer_nav_area

      Rails.cache.fetch(cache_key_for_nav_area(platform_footer_nav_area)) do
        render 'better_together/navigation_items/navigation_items',
               navigation_items: platform_footer_nav_items,
               navigation_area: platform_footer_nav_area
      end
    end

    def platform_header_nav_area
      @platform_header_nav_area ||= ::BetterTogether::NavigationArea.visible.find_by(identifier: 'platform-header')
    end

    # Retrieves navigation items for the platform header.
    def platform_header_nav_items
      # Preload navigation items and their translations in a single query
      Mobility.with_locale(current_locale) do
        @platform_header_nav_items ||= platform_header_nav_area.top_level_nav_items_includes_children || []
      end
    end

    # Retrieves navigation items for the mailer header.
    def mailer_header_nav_items
      # Preload navigation items and their translations in a single query
      Mobility.with_locale(current_locale) do
        @mailer_header_nav_items ||=
          platform_header_nav_area.top_level_nav_items_includes_children.excluding_hashed || []
      end
    end

    def render_platform_header_nav_items
      return unless platform_header_nav_area

      Rails.cache.fetch(cache_key_for_nav_area(platform_header_nav_area)) do
        render 'better_together/navigation_items/navigation_items',
               navigation_items: platform_header_nav_items,
               navigation_area: platform_header_nav_area
      end
    end

    def route_names_for_select(nav_item = nil)
      options_for_select(
        BetterTogether::NavigationItem.route_names.map do |name, route|
          [I18n.t("better_together.navigation_items.route_names.#{name}"), route]
        end,
        nav_item&.route_name
      )
    end

    protected

    def current_locale
      I18n.locale
    end

    def platform_host_nav_item
      platform_host_nav_items.find { |item| item.identifier == 'host-nav' } ||
        platform_host_nav_area&.navigation_items&.find_by(identifier: 'host-nav')
    end

    def nav_link_active?(navigation_item, path: nil)
      url = navigation_item.url
      return false if nav_url_inactive?(url)

      return true if safe_current_page?(url)

      nav_link_matches_path?(url, path:)
    end

    def nav_url_inactive?(url)
      url.blank? || url.start_with?('#')
    end

    def nav_link_matches_path?(url, path: nil)
      current_path = current_request_path(path)
      return false if current_path.blank?

      navigation_path = normalize_nav_path(url)
      current_request_path = normalize_nav_path(current_path)
      return false if navigation_path.blank? || current_request_path.blank?

      # Host dashboard should only be active on exact match, not child routes
      if navigation_path.match?(%r{/host/?$})
        current_request_path == navigation_path
      else
        current_request_path == navigation_path ||
          current_request_path.start_with?("#{navigation_path}/")
      end
    end

    def normalize_nav_path(value)
      uri = URI.parse(value.to_s)
      uri.path.presence || value.to_s
    rescue URI::InvalidURIError
      value.to_s
    end

    def current_request_path(path)
      request&.fullpath.presence || path.to_s
    end

    def safe_current_page?(url)
      current_page?(url)
    rescue StandardError
      false
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
