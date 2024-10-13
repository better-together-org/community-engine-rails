# frozen_string_literal: true

module BetterTogether
  module NavigationItemsHelper # rubocop:todo Style/Documentation
    # Retrieves navigation items for the BetterTogether header navigation.
    def better_together_nav_items
      # Preload navigation items and their translations in a single query
      Mobility.with_locale(current_locale) do
        @better_together_nav_area ||= ::BetterTogether::NavigationArea.find_by(identifier: 'better-together')
        @better_together_nav_items ||= @better_together_nav_area.top_level_nav_items_includes_children || []
      end
    end

    def dropdown_id(navigation_item)
      navigation_item.dropdown_with_visible_children? ? navigation_item.slug : nil
    end

    def dropdown_role(navigation_item)
      navigation_item.dropdown_with_visible_children? ? 'button' : nil
    end

    def dropdown_data_attributes(navigation_item)
      data = { 'identifier' => navigation_item.identifier }
      if navigation_item.dropdown_with_visible_children?
        data = data.merge({ 'bs-toggle' => 'dropdown', 'aria-expanded' => 'false' })
      end

      data
    end

    def nav_link_classes(navigation_item, path: nil)
      classes = 'nav-link'
      classes += ' dropdown-toggle' if navigation_item.dropdown_with_visible_children?
      classes += ' active' if path && path.include?(navigation_item.url)
      classes
    end

    # Retrieves navigation items for the admin area in the platform header.
    def platform_host_nav_items
      # Preload navigation items and their translations in a single query
      Mobility.with_locale(current_locale) do
        @platform_host_nav_area ||= ::BetterTogether::NavigationArea.find_by(identifier: 'platform-host')
        @platform_host_nav_items ||= @platform_host_nav_area.top_level_nav_items_includes_children || []
      end
    end

    # Retrieves navigation items for the platform footer.
    def platform_footer_nav_items
      # Preload navigation items and their translations in a single query
      Mobility.with_locale(current_locale) do
        @platform_footer_nav_area ||= ::BetterTogether::NavigationArea.find_by(identifier: 'platform-footer')
        @platform_footer_nav_items ||= @platform_footer_nav_area.top_level_nav_items_includes_children || []
      end
    end

    # Retrieves navigation items for the platform header.
    def platform_header_nav_items
      # Preload navigation items and their translations in a single query
      Mobility.with_locale(current_locale) do
        @platform_header_nav_area ||= ::BetterTogether::NavigationArea.find_by(identifier: 'platform-header')
        @platform_header_nav_items ||= @platform_header_nav_area.top_level_nav_items_includes_children || []
      end
    end

    def route_names_for_select(nav_item = nil)
      options_for_select(
        BetterTogether::NavigationItem::ROUTE_NAMES.map { |name, route| [I18n.t("route_names.#{name}"), route] },
        (nav_item ? nav_item.route_name : nil)
      )
    end

    protected

    def current_locale
      I18n.locale
    end
  end
end
