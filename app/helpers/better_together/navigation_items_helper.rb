# frozen_string_literal: true

module BetterTogether
  # rubocop:todo Metrics/ModuleLength
  module NavigationItemsHelper # rubocop:todo Style/Documentation, Metrics/ModuleLength
    def better_together_nav_area
  # rubocop:todo Layout/IndentationWidth
  @better_together_nav_area ||= ::BetterTogether::NavigationArea.find_by(identifier: 'better-together')
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
      Rails.cache.fetch(cache_key_for_nav_area(better_together_nav_area)) do
        render 'better_together/navigation_items/navigation_items', navigation_items: better_together_nav_items
      end
    end

    def cache_key_for_nav_area(nav)
      [
        'nav_area_items',
        nav.cache_key_with_version # Ensure cache expires when nav updates
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

      data
    end

    def nav_link_classes(navigation_item, path: nil)
      classes = dom_class(navigation_item, navigation_item.slug)
      classes += ' nav-link'
      classes += ' dropdown-toggle' if navigation_item.children?
      classes += ' active' if path&.include?(navigation_item.url)
      classes
    end

    def platform_host_nav_area
      @platform_host_nav_area ||= ::BetterTogether::NavigationArea.find_by(identifier: 'platform-host')
    end

    # Retrieves navigation items for the admin area in the platform header.
    def platform_host_nav_items
      # Preload navigation items and their translations in a single query
      Mobility.with_locale(current_locale) do
        @platform_host_nav_items ||= platform_host_nav_area.top_level_nav_items_includes_children || []
      end
    end

    def render_platform_host_nav_items
      Rails.cache.fetch(cache_key_for_nav_area(platform_host_nav_area)) do
        render 'better_together/navigation_items/navigation_items', navigation_items: platform_host_nav_items
      end
    end

    def platform_footer_nav_area
      @platform_footer_nav_area ||= ::BetterTogether::NavigationArea.find_by(identifier: 'platform-footer')
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
      Rails.cache.fetch(cache_key_for_nav_area(platform_footer_nav_area)) do
        render 'better_together/navigation_items/navigation_items', navigation_items: platform_footer_nav_items
      end
    end

    def platform_header_nav_area
      @platform_header_nav_area ||= ::BetterTogether::NavigationArea.find_by(identifier: 'platform-header')
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
      Rails.cache.fetch(cache_key_for_nav_area(platform_header_nav_area)) do
        render 'better_together/navigation_items/navigation_items', navigation_items: platform_header_nav_items
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
  end
  # rubocop:enable Metrics/ModuleLength
end
