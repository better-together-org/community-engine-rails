# frozen_string_literal: true

module BetterTogether
  module PagesHelper # rubocop:todo Style/Documentation
    def render_page_content(page)
      Rails.cache.fetch(['page_content', page.cache_key_with_version], expires_in: 1.minute) do
        render @page.content_blocks
      end
    end

    def pages_cache_key(pages)
      [
        'pages-index',
        pages.maximum(:updated_at),
        pages.current_page,
        pages.total_pages,
        pages.size,
        current_user&.id,
        I18n.locale,
        params[:title_filter],
        params[:slug_filter],
        params[:sort_by],
        params[:sort_direction],
        'v3'
      ]
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
      current_sort = params[:sort_by]
      current_direction = params[:sort_direction]

      # Determine new direction
      if current_sort == column.to_s
        new_direction = current_direction == 'asc' ? 'desc' : 'asc'
        icon_class = current_direction == 'asc' ? 'fas fa-sort-up' : 'fas fa-sort-down'
      else
        new_direction = 'asc'
        icon_class = 'fas fa-sort text-muted'
      end

      link_to pages_path(
        title_filter: params[:title_filter],
        sort_by: column,
        sort_direction: new_direction,
        page: params[:page]
      ), class: 'text-decoration-none d-flex align-items-center justify-content-between' do
        safe_join([
                    content_tag(:span, label),
                    content_tag(:i, '', class: icon_class, 'aria-hidden': true)
                  ])
      end
    end

    def current_title_filter
      params[:title_filter] || ''
    end

    def current_slug_filter
      params[:slug_filter] || ''
    end
  end
end
