# frozen_string_literal: true

module BetterTogether
  # rubocop:todo-next Metrics/ModuleLength
  module PagesHelper # rubocop:todo Style/Documentation, Metrics/ModuleLength
    include BetterTogether::Content::BlocksHelper

    def render_page_content(page)
      Rails.cache.fetch(
        ['page_content', page.cache_key_with_version,
         page.page_blocks.maximum(:updated_at),
         page.blocks.maximum(:updated_at),
         page_dynamic_cache_stamp(page),
         I18n.locale, page_visibility_cache_context, 'v4'],
        expires_in: 1.minute
      ) do
        render policy_scope(page.content_blocks)
      end
    end

    def pages_cache_key(pages)
      base_cache_elements(pages) + filter_cache_elements + version_cache_element
    end

    def base_cache_elements(pages)
      [
        'pages-index',
        host_platform&.id,
        pages.maximum(:updated_at),
        pages.current_page,
        pages.total_pages,
        pages.size,
        page_visibility_cache_context,
        I18n.locale
      ]
    end

    def filter_cache_elements
      [
        params[:title_filter],
        params[:slug_filter],
        params[:sort_by],
        params[:sort_direction]
      ]
    end

    def version_cache_element
      ['v1']
    end

    def page_row_cache_key(page)
      [
        'page-row',
        page.id,
        page.updated_at,
        page.page_blocks.maximum(:updated_at),
        page_visibility_cache_context,
        I18n.locale,
        'v2'
      ]
    end

    def page_show_cache_key(page)
      [
        'page-show',
        page.id,
        page.updated_at,
        page.page_blocks.maximum(:updated_at),
        page.blocks.maximum(:updated_at),
        page.contributions.maximum(:updated_at),
        page_dynamic_cache_stamp(page),
        page.sidebar_nav&.cache_key_with_version,
        (breadcrumb_trail_cache_key(page) if respond_to?(:breadcrumb_trail_cache_key, true)),
        page_visibility_cache_context,
        I18n.locale,
        'v7'
      ]
    end

    # Plan blocks depend on who is looking (offer rules, memberships), which the shared
    # page fragment key does not capture, so pages holding them are rendered uncached.
    def page_has_viewer_specific_blocks?(blocks)
      blocks.any? do |block|
        block.is_a?(BetterTogether::Content::PlanButtonBlock) ||
          block.is_a?(BetterTogether::Content::PlanCatalogBlock)
      end
    end

    # What the page's record-listing blocks (posts, events, people, communities) hold right now for this viewer,
    # so a cached page is rebuilt when their lists change rather than frozen at the last page edit.
    def page_dynamic_cache_stamp(page)
      page.content_blocks.filter_map { |block| dynamic_block_cache_stamp(block) }
    end

    def sortable_column_header(column, label)
      sort_info = calculate_sort_info(column)

      link_to build_sort_path(column, sort_info[:direction]), sort_link_options do
        build_sort_content(label, sort_info[:icon_class])
      end
    end

    def calculate_sort_info(column)
      if currently_sorted_by?(column)
        active_column_sort_info
      else
        default_column_sort_info
      end
    end

    def currently_sorted_by?(column)
      params[:sort_by] == column.to_s
    end

    def active_column_sort_info
      current_direction = params[:sort_direction]
      {
        direction: current_direction == 'asc' ? 'desc' : 'asc',
        icon_class: current_direction == 'asc' ? 'fas fa-sort-up' : 'fas fa-sort-down'
      }
    end

    def default_column_sort_info
      {
        direction: 'asc',
        icon_class: 'fas fa-sort text-muted'
      }
    end

    def build_sort_path(column, direction)
      pages_path(
        title_filter: params[:title_filter],
        sort_by: column,
        sort_direction: direction,
        page: params[:page]
      )
    end

    def sort_link_options
      { class: 'text-decoration-none d-flex align-items-center justify-content-between' }
    end

    def build_sort_content(label, icon_class)
      safe_join([
                  content_tag(:span, label),
                  content_tag(:i, '', class: icon_class, 'aria-hidden': true)
                ])
    end

    def current_title_filter
      params[:title_filter] || ''
    end

    def current_slug_filter
      params[:slug_filter] || ''
    end
  end
end
