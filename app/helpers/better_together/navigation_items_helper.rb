# frozen_string_literal: true

require 'digest'

module BetterTogether
  # rubocop:todo Metrics/ModuleLength
  module NavigationItemsHelper # rubocop:todo Style/Documentation, Metrics/ModuleLength
    HOST_DASHBOARD_TURBO_FRAME_ID = 'host-dashboard-tab-content'
    HOST_DASHBOARD_TAB_IDENTIFIERS = %w[
      host-dashboard
      host-dashboard-membership-review
      host-dashboard-platform-connection-review
      host-dashboard-safety-review
    ].freeze
    SPECIAL_HOST_DASHBOARD_NAV_VISIBILITY = {
      'host-dashboard-membership-review' => ['manage_platform'],
      'host-dashboard-platform-connection-review' => %w[
        manage_network_connections
        approve_network_connections
      ],
      'host-dashboard-safety-review' => ['manage_platform_safety']
    }.freeze

    NAV_TREE_PRELOADS = [
      :string_translations,
      { linkable: [:string_translations] },
      {
        children: [
          :string_translations,
          { linkable: [:string_translations] },
          {
            children: [
              :string_translations,
              { linkable: [:string_translations] }
            ]
          }
        ]
      }
    ].freeze

    def better_together_nav_area
  # rubocop:todo Layout/IndentationWidth
  @better_together_nav_area ||= ::BetterTogether::NavigationArea.visible.find_by(identifier: 'better-together')
      # rubocop:enable Layout/IndentationWidth
    end

    # Retrieves navigation items for the BetterTogether header navigation.
    def better_together_nav_items
      visible_nav_items_for(better_together_nav_area)
    end

    def render_better_together_nav_items
      return unless better_together_nav_area

      Rails.cache.fetch(cache_key_for_nav_area(better_together_nav_area)) do
        render_navigation_items_list(
          navigation_items: better_together_nav_items,
          navigation_area: better_together_nav_area
        )
      end
    end

    def cache_key_for_nav_area(nav)
      context_key = nav_visibility_context_key
      return default_nav_cache_key(nav) if context_key.blank?

      [
        'nav_area_items',
        nav.cache_key_with_version, # Ensure cache expires when nav updates
        context_key
      ]
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

      if (turbo_frame_target = navigation_item_turbo_frame_target(navigation_item))
        data = data.merge({ turbo_frame: turbo_frame_target, turbo_action: 'advance' })
      end

      data
    end

    def nav_link_classes(navigation_item, path: nil)
      classes = dom_class(navigation_item, navigation_item.slug)
      classes += ' nav-link text-center'
      classes += ' dropdown-toggle' if navigation_item.children?
      # Don't add 'active' class here - it's request-dependent and breaks caching
      # The active state is handled client-side via Stimulus or via data attribute
      classes += ' active' if nav_link_active?(navigation_item, path:)
      classes
    end

    def platform_host_nav_area
      @platform_host_nav_area ||= ::BetterTogether::NavigationArea.visible.find_by(identifier: 'platform-host')
    end

    # Retrieves navigation items for the admin area in the platform header.
    def platform_host_nav_items
      visible_nav_items_for(platform_host_nav_area)
    end

    def render_platform_host_nav_items
      return unless platform_host_nav_area

      Rails.cache.fetch(cache_key_for_nav_area(platform_host_nav_area)) do
        render_navigation_items_list(
          navigation_items: platform_host_nav_items,
          navigation_area: platform_host_nav_area
        )
      end
    end

    def platform_host_nav_visible?
      return false unless current_user

      platform_host_nav_items.any? { |item| navigation_item_visible_for?(item, platform: host_platform) }
    end

    # rubocop:todo Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    # rubocop:todo Metrics/AbcSize
    def navigation_item_visible_for?(navigation_item, platform: host_platform)
      return false unless navigation_item

      @navigation_item_visibility_cache ||= {}
      cache_key = [navigation_item.id, platform&.id, current_user&.id]
      return @navigation_item_visibility_cache[cache_key] if @navigation_item_visibility_cache.key?(cache_key)

      visible = special_navigation_item_visible?(navigation_item) ||
                navigation_item.visible_to?(current_user, platform:) ||
                (navigation_item.dropdown? &&
                  navigation_item.children.any? { |child| navigation_item_visible_for?(child, platform:) })

      @navigation_item_visibility_cache[cache_key] = visible
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def navigation_item_children_for(navigation_item, platform: host_platform)
      @navigation_item_children_cache ||= {}
      cache_key = [navigation_item.id, platform&.id, current_user&.id]
      return @navigation_item_children_cache[cache_key] if @navigation_item_children_cache.key?(cache_key)

      visible_children = navigation_item.children.select { |child| navigation_item_visible_for?(child, platform:) }
      @navigation_item_children_cache[cache_key] = visible_children
    end

    def platform_host_nav_children
      return [] unless platform_host_nav_area

      host_nav = platform_host_nav_item
      return [] unless host_nav

      children = host_nav.children.visible
      children.select { |child| navigation_item_visible_for?(child, platform: host_platform) }
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
      visible_nav_items_for(platform_footer_nav_area)
    end

    def render_platform_footer_nav_items
      return unless platform_footer_nav_area

      Rails.cache.fetch(cache_key_for_nav_area(platform_footer_nav_area)) do
        render_navigation_items_list(
          navigation_items: platform_footer_nav_items,
          navigation_area: platform_footer_nav_area
        )
      end
    end

    def platform_header_nav_area
      @platform_header_nav_area ||= ::BetterTogether::NavigationArea.visible.find_by(identifier: 'platform-header')
    end

    # Retrieves navigation items for the platform header.
    def platform_header_nav_items
      visible_nav_items_for(platform_header_nav_area)
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
        render_navigation_items_list(
          navigation_items: platform_header_nav_items,
          navigation_area: platform_header_nav_area
        )
      end
    end

    def nav_fragment_cache_key(fragment_name, nav_areas: [])
      nav_area_keys = Array(nav_areas).compact.map(&:cache_key_with_version).sort
      [
        'layout_fragment',
        fragment_name,
        "locale:#{current_locale}",
        "platform:#{host_platform&.cache_key_with_version || 'none'}",
        "community:#{host_community&.cache_key_with_version || 'none'}",
        "areas:#{Digest::SHA256.hexdigest(nav_area_keys.join('|'))}",
        "visibility:#{nav_visibility_context_key}"
      ]
    end

    def route_names_for_select(nav_item = nil)
      options_for_select(
        BetterTogether::NavigationItem.route_names.map do |name, route|
          [I18n.t("better_together.navigation_items.route_names.#{name}"), route]
        end,
        nav_item&.route_name
      )
    end

    def navigation_item_turbo_frame_target(navigation_item)
      return unless params[:controller] == 'better_together/host_dashboard'
      return unless HOST_DASHBOARD_TAB_IDENTIFIERS.include?(navigation_item.identifier)

      HOST_DASHBOARD_TURBO_FRAME_ID
    end

    def special_navigation_item_visible?(navigation_item)
      permissions = SPECIAL_HOST_DASHBOARD_NAV_VISIBILITY[navigation_item.identifier]
      return false if permissions.blank?

      permissions.any? { |permission| current_person&.permitted_to?(permission) }
    end

    # Renders a navigation items list with optional navigation area styling
    # @param navigation_items [Array<NavigationItem>] The navigation items to render
    # @param navigation_area [NavigationArea, nil] Optional navigation area for DOM classes/IDs
    # @param justify [String] Bootstrap justify class (default: 'center')
    # @param base_class [String] Base navbar class (default: 'navbar-nav')
    # @param flex_direction_class [String] Responsive flex direction (default: 'flex-lg-row')
    # @param flex_wrap_class [String] Flex wrapping behavior (default: 'flex-wrap')
    # @param gap_class [String] Default gap spacing (default: 'gap-2')
    # @param gap_md_class [String] Medium breakpoint gap spacing (default: 'gap-md-3')
    # @return [String] HTML ul element with navigation items
    # rubocop:disable Metrics/ParameterLists
    def render_navigation_items_list(
      navigation_items:,
      navigation_area: nil,
      justify: 'center',
      base_class: 'navbar-nav',
      flex_direction_class: 'flex-lg-row',
      flex_wrap_class: 'flex-wrap',
      gap_class: 'gap-2',
      gap_md_class: 'gap-md-3'
    )
      # rubocop:enable Metrics/ParameterLists
      nav_class = [
        base_class,
        flex_direction_class,
        flex_wrap_class,
        gap_class,
        gap_md_class,
        "justify-content-#{justify}"
      ].compact.join(' ')
      nav_class += " #{dom_class(navigation_area, :nav_items)}" if navigation_area
      nav_id = navigation_area ? dom_id(navigation_area, :nav_items) : nil

      content_tag :ul, class: nav_class, id: nav_id do
        render partial: 'better_together/navigation_items/navigation_item',
               collection: navigation_items, as: :navigation_item
      end
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

    private

    def visible_nav_items_for(nav_area)
      return [] unless nav_area

      cache = visible_navigation_items_cache
      key = visible_nav_items_cache_key(nav_area)
      return cache[key] if cache.key?(key)

      cache[key] = load_nav_items_for(nav_area).select { |item| navigation_item_visible_for?(item, platform: host_platform) }
    end

    # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def nav_visibility_context_key
      build_nav_visibility_context_key
    end

    # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def build_nav_visibility_context_key
      context_parts = [
        "locale:#{current_locale}",
        "platform:#{host_platform&.cache_key_with_version || 'none'}",
        "auth:#{current_user ? 'user' : 'guest'}",
        "user:#{current_user&.cache_key_with_version || 'none'}",
        "permissions:#{nav_permission_cache_stamp}",
        "path:#{request&.path.to_s.hash}"
      ]

      return nil if context_parts.any?(&:blank?)

      Digest::SHA256.hexdigest(context_parts.join('|'))
    rescue StandardError
      nil
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    def nav_permission_cache_stamp
      context_key = current_user&.cache_key_with_version || 'guest'
      @nav_permission_cache_stamp_cache ||= {}
      return @nav_permission_cache_stamp_cache[context_key] if @nav_permission_cache_stamp_cache.key?(context_key)

      @nav_permission_cache_stamp_cache[context_key] =
        if current_user.nil?
          'guest'
        else
          segments = [context_key]
          segments.concat(membership_cache_segments)
          segments.concat(role_cache_segments)
          Digest::SHA256.hexdigest(segments.compact.join('|'))
        end
    end

    # rubocop:todo Metrics/AbcSize
    def membership_cache_segments
      context_key = current_user&.cache_key_with_version || 'guest'
      @membership_cache_segments_cache ||= {}
      return @membership_cache_segments_cache[context_key] if @membership_cache_segments_cache.key?(context_key)

      @membership_cache_segments_cache[context_key] = membership_segments_for_user
    end
    # rubocop:enable Metrics/AbcSize

    def role_cache_segments
      context_key = current_user&.cache_key_with_version || 'guest'
      @role_cache_segments_cache ||= {}
      return @role_cache_segments_cache[context_key] if @role_cache_segments_cache.key?(context_key)

      @role_cache_segments_cache[context_key] = begin
        if current_user.respond_to?(:roles)
          roles_scope = current_user.roles
          max_updated_at = roles_scope.maximum(:updated_at).to_i
          ["roles:#{roles_scope.count}:#{max_updated_at}"]
        else
          []
        end
      rescue StandardError
        []
      end
    end

    def default_nav_cache_key(nav)
      [
        'nav_area_items',
        nav.cache_key_with_version,
        current_user&.cache_key_with_version,
        request.path.hash
      ].compact
    end

    def visible_navigation_items_cache
      @visible_navigation_items_cache ||= {}
    end

    def visible_nav_items_cache_key(nav_area)
      [nav_area.id, nav_area.cache_key_with_version, nav_visibility_context_key]
    end

    def load_nav_items_for(nav_area)
      Mobility.with_locale(current_locale) do
        relation = nav_area.top_level_nav_items_includes_children
        relation = relation.includes(NAV_TREE_PRELOADS) if relation.respond_to?(:includes)
        relation.to_a
      end
    end

    def membership_segments_for_user
      return [] unless current_user.class.respond_to?(:joinable_membership_classes)

      current_user.class.joinable_membership_classes.filter_map do |membership_class_name|
        membership_segment_for(membership_class_name)
      end
    end

    def membership_segment_for(membership_class_name)
      membership_class = membership_class_name.to_s.safe_constantize
      return nil unless membership_class&.column_names&.include?('member_id')

      scope = membership_class.where(member_id: current_user.id)
      max_updated_at = scope.maximum(:updated_at).to_i
      "#{membership_class_name}:#{scope.count}:#{max_updated_at}"
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
