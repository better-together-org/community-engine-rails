# frozen_string_literal: true

module BetterTogether
  # Breadcrumb trail for pages, built from the navigation hierarchy, plus the
  # JSON-LD to render it. A page outside any navigation tree gets Home > page.
  module BreadcrumbsHelper
    Crumb = Struct.new(:title, :url, keyword_init: true)

    # Trail from home to the page, memoized per request. Empty for the home page.
    def breadcrumb_trail_for(page)
      @breadcrumb_trails ||= {}
      @breadcrumb_trails[page.id] ||= build_breadcrumb_trail(page)
    end

    # Stable key part so cached page markup follows navigation and title changes.
    def breadcrumb_trail_cache_key(page)
      Digest::SHA256.hexdigest(breadcrumb_trail_for(page).map { |crumb| [crumb.title, crumb.url] }.to_json)
    end

    # Schema.org BreadcrumbList for the trail. Entries without a URL are skipped.
    def breadcrumb_list_json_ld(trail, current_url:)
      items = trail.map { |crumb| [crumb.title, crumb.url] }
      items.last[1] ||= current_url if items.any?
      elements = items.select { |(_title, url)| url.present? }.each_with_index.map do |(title, url), index|
        { '@type' => 'ListItem', 'position' => index + 1, 'name' => title, 'item' => absolute_breadcrumb_url(url) }
      end

      { '@context' => 'https://schema.org', '@type' => 'BreadcrumbList', 'itemListElement' => elements }
    end

    private

    def build_breadcrumb_trail(page)
      return [] if breadcrumb_home_page?(page)

      home = Crumb.new(title: t('breadcrumbs.home'), url: base_path_with_locale)
      ancestors = navigation_breadcrumbs_for(page) || []

      [home, *ancestors, Crumb.new(title: page.title, url: nil)]
    end

    def breadcrumb_home_page?(page)
      page.identifier == 'home' || page.slug == 'home'
    end

    # Ancestors of the page's navigation item (header area first), or nil when
    # the page is not in a navigation tree.
    def navigation_breadcrumbs_for(page)
      items = ::BetterTogether::NavigationItem.where(linkable: page).includes(:navigation_area).to_a
      return if items.empty?

      header_id = platform_header_nav_area&.id
      item = items.find { |candidate| candidate.navigation_area_id == header_id } || items.first
      return unless navigation_item_visible_for?(item)

      navigation_ancestors(item).map { |ancestor| navigation_crumb(ancestor) }
    end

    def navigation_ancestors(item)
      ancestors = []
      while (item = item.parent)
        ancestors.unshift(item)
      end
      ancestors
    end

    # Dropdown headings have no page of their own; they render as plain text.
    def navigation_crumb(item)
      url = item.url.to_s
      Crumb.new(title: item.title, url: url.start_with?('#') || url.blank? ? nil : url)
    end

    def absolute_breadcrumb_url(url)
      url.to_s.start_with?('http://', 'https://') ? url : "#{base_url}#{url}"
    end
  end
end
