# frozen_string_literal: true

module BetterTogether
  # rubocop:todo Metrics/ModuleLength
  module PagesHelper # rubocop:todo Style/Documentation, Metrics/ModuleLength
    def render_page_content(page)
  # rubocop:todo Layout/IndentationWidth
  Rails.cache.fetch(['page_content', page.cache_key_with_version], expires_in: 1.minute) do
    # rubocop:enable Layout/IndentationWidth
    render @page.content_blocks
  end
    end

    def pages_cache_key(pages)
      base_cache_elements(pages) + filter_cache_elements + version_cache_element
    end

    def base_cache_elements(pages)
      [
        'pages-index',
        pages.maximum(:updated_at),
        pages.current_page,
        pages.total_pages,
        pages.size,
        current_user&.id,
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
        current_user&.id,
        I18n.locale,
        'v1'
      ]
    end

    def page_show_cache_key(page)
      [
        'page-show',
        page.id,
        page.updated_at,
        page.page_blocks.maximum(:updated_at),
        page.blocks.maximum(:updated_at),
        current_user&.id,
        I18n.locale,
        'v1'
      ]
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
  # rubocop:enable Metrics/ModuleLength
end
