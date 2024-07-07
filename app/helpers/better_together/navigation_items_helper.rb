# frozen_string_literal: true

module BetterTogether
  module NavigationItemsHelper # rubocop:todo Style/Documentation
    # Retrieves navigation items for the BetterTogether header navigation.
    def better_together_nav_items
      # Preload navigation items and their translations in a single query
      # @better_together_nav_area ||= ::BetterTogether::NavigationArea.includes(navigation_items: [:text_translations])
      #                                                               .friendly.find('better-together')
      @better_together_nav_area ||= ::BetterTogether::NavigationArea.friendly.find('better-together')
      @better_together_nav_items ||= @better_together_nav_area.top_level_nav_items_includes_children || []
    end

    def dropdown_id(navigation_item)
      navigation_item.dropdown? ? navigation_item.slug : nil
    end

    def dropdown_role(navigation_item)
      navigation_item.dropdown? ? 'button' : nil
    end

    def dropdown_data_attributes(navigation_item)
      if navigation_item.dropdown?
        { 'bs-toggle' => 'dropdown', 'aria-expanded' => 'false' }
      else
        {}
      end
    end

    def nav_link_classes(navigation_item)
      classes = 'nav-link'
      classes += ' dropdown-toggle' if navigation_item.dropdown?
      classes
    end

    # Retrieves navigation items for the admin area in the platform header.
    def platform_header_admin_nav_items
      # Preload navigation items and their translations in a single query
      # rubocop:todo Layout/LineLength
      # @platform_header_admin_nav_area ||= ::BetterTogether::NavigationArea.includes(navigation_items: [:text_translations])
      # rubocop:enable Layout/LineLength
      #                                                               .friendly.find('platform-header-admin')
      @platform_header_admin_nav_area ||= ::BetterTogether::NavigationArea.friendly.find('platform-header-admin')
      @platform_header_admin_nav_items ||= @platform_header_admin_nav_area.top_level_nav_items_includes_children || []
    end

    # Retrieves navigation items for the platform footer.
    def platform_footer_nav_items
      # Preload navigation items and their translations in a single query
      # @platform_footer_nav_area ||= ::BetterTogether::NavigationArea.includes(navigation_items: [:text_translations])
      #                                                               .friendly.find('platform-footer')
      @platform_footer_nav_area ||= ::BetterTogether::NavigationArea.friendly.find('platform-footer')
      @platform_footer_nav_items ||= @platform_footer_nav_area.top_level_nav_items_includes_children || []
    end

    # Retrieves navigation items for the platform header.
    def platform_header_nav_items
      # Preload navigation items and their translations in a single query
      # @platform_header_nav_area ||= ::BetterTogether::NavigationArea.includes(navigation_items: [:text_translations])
      #                                                               .friendly.find('platform-header')
      #
      @platform_header_nav_area ||= ::BetterTogether::NavigationArea.friendly.find('platform-header')
      @platform_header_nav_items ||= @platform_header_nav_area.top_level_nav_items_includes_children || []
    end
  end
end
