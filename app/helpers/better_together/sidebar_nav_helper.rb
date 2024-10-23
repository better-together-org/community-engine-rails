module BetterTogether
  # app/helpers/sidebar_nav_helper.rb
  module SidebarNavHelper
    def render_sidebar_nav(nav:, current_page:)
      content_tag :div, class: 'accordion', id: 'sidebar_nav_accordion' do
        nav.navigation_items.positioned.top_level.map.with_index do |nav_item, index|
          render_nav_item(nav_item: nav_item, current_page: current_page, level: 0, parent_id: "sidebar_nav_accordion", index: index)
        end.join.html_safe
      end
    end

    def render_nav_item(nav_item:, current_page:, level:, parent_id:, index:)
      # Define the heading tag dynamically based on the level
      heading_tag = "h#{[3 + level, 6].min}"

      # Collapse ID for this item
      collapse_id = "collapse_#{nav_item.id}"

      # Determine if the nav_item is active (if its linkable matches the current_page)
      is_active = nav_item.linkable == current_page

      # Determine if any child item is the current page, which would require this parent to be expanded
      has_active_child = nav_item.children&.any? { |child_item| child_item.linkable == current_page || has_active_children?(child_item, current_page) }

      # If this item is active or has an active child, it should be expanded
      should_expand = is_active || has_active_child

      # Define whether the collapse section should be expanded based on activity
      expanded_class = should_expand ? "show" : ""
      expanded_state = should_expand ? "true" : "false"
      link_classes = "btn-sidebar-nav text-decoration-none"
      link_classes += is_active ? " active" : " collapsed"

      content_tag :div, class: "accordion-item py-2 level-#{level}" do
        # Render all items with heading tags
        item_content = content_tag(heading_tag, class: 'accordion-header', id: "heading_#{collapse_id}") do
          header_content = if nav_item.linkable
            # Use the same link for both the collapse toggle and navigation to the linkable page
           link_to nav_item.title, (nav_item.linkable ? render_page_path(nav_item.linkable.slug) : '#'), class: link_classes
          else
            # If it doesn't have children or a linkable, render it as a simple heading
            content_tag(:span, nav_item.title, class: 'non-collapsible', 'aria-expanded': "false")
          end

          if nav_item.children?
            header_content += link_to '#', class: "sidebar-level-toggle #{link_classes}", 'data-bs-toggle': 'collapse', 'data-bs-target': "##{collapse_id}", 'aria-expanded': expanded_state, 'aria-controls': collapse_id do
              '<i class="fas fa-caret-down me-2"></i>'.html_safe
            end
          end

          header_content
        end

        # Render collapsible content for child items
        if nav_item.children?
          item_content += content_tag(:div, id: collapse_id, class: "accordion-collapse collapse #{expanded_class}", 'aria-labelledby': "heading_#{collapse_id}", 'data-bs-parent': "##{parent_id}") do
            content_tag :div, class: 'accordion-body' do
              nav_item.children.visible.map.with_index do |child_item, child_index|
                render_nav_item(nav_item: child_item, current_page: current_page, level: level + 1, parent_id: collapse_id, index: child_index)
              end.join.html_safe
            end
          end
        end

        item_content
      end
    end

    # Helper method to recursively check if any descendants are active
    def has_active_children?(nav_item, current_page)
      nav_item.children&.any? do |child|
        child.linkable == current_page || has_active_children?(child, current_page)
      end
    end
  end
end
