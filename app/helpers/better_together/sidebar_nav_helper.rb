# frozen_string_literal: true

module BetterTogether
  module SidebarNavHelper
    def render_sidebar_nav(nav:, current_page:)
      # Generate a unique cache key for the navigation
      cache_key = [
        'sidebar_nav',
        nav.cache_key_with_version,
        "page-#{current_page.id}"
      ]

      # Use Rails' cache helper to cache the rendered output
      Rails.cache.fetch(cache_key) do
        # Preload all navigation items and their linkable translations in one go, limiting it to `visible` items
        nav_items = nav.navigation_items.positioned.includes(:string_translations, linkable: %i[string_translations])

        # Organize items by id for fast lookups
        @nav_item_cache = nav_items.index_by(&:id)
        # Organize children by parent_id for hierarchical lookup
        @nav_item_children = nav_items.group_by(&:parent_id)

        # Render only top-level items (those without a parent_id)
        content_tag :div, class: 'accordion', id: 'sidebar_nav_accordion' do
          nav_items.select { |ni| ni.parent_id.nil? }.map.with_index do |nav_item, index|
            render_nav_item(nav_item: nav_item, current_page: current_page, level: 0,
                            parent_id: 'sidebar_nav_accordion', index: index)
          end.join.html_safe
        end
      end
    end

    def render_nav_item(nav_item:, current_page:, level:, parent_id:, index:)
      heading_tag = "h#{[3 + level, 6].min}"
      collapse_id = "collapse_#{nav_item.id}"

      linkable = nav_item.linkable
      has_children = @nav_item_children[nav_item.id]&.any?
      children = @nav_item_children[nav_item.id] || []

      # Determine if the current nav_item or any of its descendants is active
      is_active = linkable == current_page
      has_active_child = has_active_descendants?(nav_item.id, current_page)

      should_expand = is_active || has_active_child
      expanded_class = should_expand ? 'show' : ''
      expanded_state = should_expand ? 'true' : 'false'
      link_classes = 'btn-sidebar-nav text-decoration-none'
      link_classes += is_active ? ' active' : ' collapsed'

      content_tag :div, class: "accordion-item py-2 level-#{level}" do
        item_content = content_tag(heading_tag, class: 'accordion-header', id: "heading_#{collapse_id}") do
          header_content = if linkable
                             link_to nav_item.title, render_page_path(linkable.slug), class: link_classes
                           else
                             content_tag(:span, nav_item.title, class: 'non-collapsible', 'aria-expanded': 'false')
                           end

          if has_children
            header_content += link_to '#', class: "sidebar-level-toggle #{link_classes}", 'data-bs-toggle': 'collapse',
                                           'data-bs-target': "##{collapse_id}", 'aria-expanded': expanded_state, 'aria-controls': collapse_id do
              '<i class="fas me-2"></i>'.html_safe
            end
          end

          header_content
        end

        # Render children if they exist
        if has_children
          item_content += content_tag(:div, id: collapse_id, class: "accordion-collapse collapse #{expanded_class}",
                                            'aria-labelledby': "heading_#{collapse_id}", 'data-bs-parent': "##{parent_id}") do
            content_tag :div, class: 'accordion-body' do
              children.map.with_index do |child_item, child_index|
                render_nav_item(nav_item: child_item, current_page: current_page, level: level + 1,
                                parent_id: collapse_id, index: child_index)
              end.join.html_safe
            end
          end
        end

        item_content
      end
    end

    # Memoized method to check if any descendants are active
    def has_active_descendants?(nav_item_id, current_page)
      @active_descendant_cache ||= {}
      return @active_descendant_cache[nav_item_id] if @active_descendant_cache.key?(nav_item_id)

      children = @nav_item_children[nav_item_id] || []
      @active_descendant_cache[nav_item_id] = children.any? do |child|
        child.linkable == current_page || has_active_descendants?(child.id, current_page)
      end
    end
  end
end
