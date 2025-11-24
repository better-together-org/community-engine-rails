# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SidebarNavHelper do
  # Include engine routes for path helpers
  include BetterTogether::Engine.routes.url_helpers

  let(:community) { @community }
  let(:nav) { @nav }
  let(:parent_page) { @parent_page }
  let(:child_page) { @child_page }
  let(:grandchild_page) { @grandchild_page }
  let(:current_page) { parent_page }

  before do
    configure_host_platform
    @community = BetterTogether::Platform.host.first.community
    @nav = create(:better_together_navigation_area, navigable: @community)

    # Define render_page_path helper for specs (it's a catch-all route)
    def helper.render_page_path(slug)
      "/#{slug}"
    end

    # Create pages for linking (pages don't have community association)
    @parent_page = create(:better_together_page, slug: 'parent-page', protected: false)
    @child_page = create(:better_together_page, slug: 'child-page', protected: false)
    @grandchild_page = create(:better_together_page, slug: 'grandchild-page', protected: false)

    # Clear cache before each test
    Rails.cache.clear
  end

  describe '#render_sidebar_nav' do
    context 'with no navigation items' do
      it 'renders empty accordion structure' do
        result = helper.render_sidebar_nav(nav:, current_page:)

        expect(result).to have_css('div.accordion#sidebar_nav_accordion')
        expect(result).not_to have_css('.accordion-item')
      end
    end

    context 'with single top-level item' do
      let!(:nav_item) do
        create(:better_together_navigation_item,
               navigation_area: nav,
               linkable: parent_page,
               position: 1,
               parent_id: nil)
      end

      it 'renders the navigation item' do
        result = helper.render_sidebar_nav(nav:, current_page:)

        expect(result).to have_css('.accordion-item')
        expect(result).to have_link(nav_item.title)
      end

      it 'marks current page as active' do
        result = helper.render_sidebar_nav(nav:, current_page: parent_page)

        expect(result).to have_css('a.btn-sidebar-nav.active')
      end

      it 'does not mark other pages as active' do
        result = helper.render_sidebar_nav(nav:, current_page: child_page)

        expect(result).to have_css('a.btn-sidebar-nav.collapsed')
        expect(result).not_to have_css('a.btn-sidebar-nav.active')
      end
    end

    context 'with hierarchical navigation items' do
      let!(:parent_nav_item) do
        create(:better_together_navigation_item,
               navigation_area: nav,
               linkable: parent_page,
               position: 1,
               parent_id: nil)
      end

      let!(:child_nav_item) do
        create(:better_together_navigation_item,
               navigation_area: nav,
               linkable: child_page,
               position: 1,
               parent_id: parent_nav_item.id)
      end

      let!(:grandchild_nav_item) do
        create(:better_together_navigation_item,
               navigation_area: nav,
               linkable: grandchild_page,
               position: 1,
               parent_id: child_nav_item.id)
      end

      it 'renders nested accordion structure' do
        result = helper.render_sidebar_nav(nav:, current_page:)

        expect(result).to have_css('.accordion-item.level-0')
        expect(result).to have_css('.accordion-item.level-1')
        expect(result).to have_css('.accordion-item.level-2')
      end

      it 'includes collapse toggle for items with children' do
        result = helper.render_sidebar_nav(nav:, current_page:)

        expect(result).to have_css('a.sidebar-level-toggle[data-bs-toggle="collapse"]')
      end

      it 'expands parent when child is active' do
        result = helper.render_sidebar_nav(nav:, current_page: child_page)
        doc = Nokogiri::HTML(result)

        collapse_div = doc.css("#collapse_#{parent_nav_item.id}").first
        expect(collapse_div['class']).to include('show')
      end

      it 'expands ancestors when grandchild is active' do
        result = helper.render_sidebar_nav(nav:, current_page: grandchild_page)
        doc = Nokogiri::HTML(result)

        parent_collapse = doc.css("#collapse_#{parent_nav_item.id}").first
        child_collapse = doc.css("#collapse_#{child_nav_item.id}").first

        expect(parent_collapse['class']).to include('show')
        expect(child_collapse['class']).to include('show')
      end

      it 'does not expand unrelated branches' do
        other_page = create(:better_together_page, slug: 'other-page')
        other_nav_item = create(:better_together_navigation_item,
                                navigation_area: nav,
                                linkable: other_page,
                                position: 2,
                                parent_id: nil)

        result = helper.render_sidebar_nav(nav:, current_page: child_page)
        doc = Nokogiri::HTML(result)

        other_collapse = doc.css("#collapse_#{other_nav_item.id}").first
        expect(other_collapse).to be_nil # No children, so no collapse div
      end
    end

    context 'with navigation items without linkable' do
      let!(:nav_item_without_link) do
        create(:better_together_navigation_item,
               navigation_area: nav,
               linkable: nil,
               position: 1,
               parent_id: nil)
      end

      it 'renders span instead of link' do
        result = helper.render_sidebar_nav(nav:, current_page:)

        expect(result).to have_css('span.non-collapsible')
        expect(result).not_to have_link(nav_item_without_link.title)
      end
    end

    context 'caching behavior' do
      let!(:nav_item) do
        create(:better_together_navigation_item,
               navigation_area: nav,
               linkable: parent_page,
               position: 1)
      end

      it 'caches the rendered navigation' do
        # First call should cache
        first_result = helper.render_sidebar_nav(nav:, current_page:)

        # Second call should use cache
        expect(Rails.cache).to receive(:fetch).and_call_original
        second_result = helper.render_sidebar_nav(nav:, current_page:)

        expect(first_result).to eq(second_result)
      end

      it 'uses different cache keys for different current pages' do
        result1 = helper.render_sidebar_nav(nav:, current_page: parent_page)
        result2 = helper.render_sidebar_nav(nav:, current_page: child_page)

        # Results should be different because active states differ
        expect(result1).not_to eq(result2)
      end
    end

    context 'with multiple positioned items' do
      let!(:first_item) do
        create(:better_together_navigation_item,
               navigation_area: nav,
               linkable: parent_page,
               position: 1,
               parent_id: nil)
      end

      let!(:second_item) do
        create(:better_together_navigation_item,
               navigation_area: nav,
               linkable: child_page,
               position: 2,
               parent_id: nil)
      end

      it 'renders items in position order' do
        result = helper.render_sidebar_nav(nav:, current_page:)
        doc = Nokogiri::HTML(result)

        items = doc.css('.accordion-item.level-0')
        expect(items.count).to eq(2)
      end
    end
  end

  describe '#render_nav_item' do
    let!(:nav_item) do
      create(:better_together_navigation_item,
             navigation_area: nav,
             linkable: parent_page,
             position: 1,
             parent_id: nil)
    end

    before do
      # Set up instance variables that render_nav_item expects
      nav_items = nav.navigation_items.positioned.includes(:string_translations, linkable: %i[string_translations])
      helper.instance_variable_set(:@nav_item_cache, nav_items.index_by(&:id))
      helper.instance_variable_set(:@nav_item_children, nav_items.group_by(&:parent_id))
    end

    it 'renders accordion item with correct level class' do
      result = helper.render_nav_item(
        nav_item:,
        current_page:,
        level: 0,
        parent_id: 'sidebar_nav_accordion',
        index: 0
      )

      expect(result).to have_css('.accordion-item.level-0')
    end

    it 'uses h3 for level 0' do
      result = helper.render_nav_item(
        nav_item:,
        current_page:,
        level: 0,
        parent_id: 'sidebar_nav_accordion',
        index: 0
      )

      expect(result).to have_css('h3.accordion-header')
    end

    it 'uses h4 for level 1' do
      child_nav_item = create(:better_together_navigation_item,
                              navigation_area: nav,
                              linkable: child_page,
                              parent_id: nav_item.id,
                              position: 1)

      # Refresh instance variables
      nav_items = nav.navigation_items.positioned.includes(:string_translations, linkable: %i[string_translations])
      helper.instance_variable_set(:@nav_item_cache, nav_items.index_by(&:id))
      helper.instance_variable_set(:@nav_item_children, nav_items.group_by(&:parent_id))

      result = helper.render_nav_item(
        nav_item: child_nav_item,
        current_page:,
        level: 1,
        parent_id: "collapse_#{nav_item.id}",
        index: 0
      )

      expect(result).to have_css('h4.accordion-header')
    end

    it 'limits heading level to h6 for deep nesting' do
      deep_item = create(:better_together_navigation_item,
                         navigation_area: nav,
                         linkable: parent_page,
                         position: 1)

      nav_items = nav.navigation_items.positioned.includes(:string_translations, linkable: %i[string_translations])
      helper.instance_variable_set(:@nav_item_cache, nav_items.index_by(&:id))
      helper.instance_variable_set(:@nav_item_children, nav_items.group_by(&:parent_id))

      result = helper.render_nav_item(
        nav_item: deep_item,
        current_page:,
        level: 10,
        parent_id: 'parent',
        index: 0
      )

      expect(result).to have_css('h6.accordion-header')
    end
  end

  describe '#has_active_descendants?' do
    let!(:parent_nav_item) do
      create(:better_together_navigation_item,
             navigation_area: nav,
             linkable: parent_page,
             position: 1,
             parent_id: nil)
    end

    let!(:child_nav_item) do
      create(:better_together_navigation_item,
             navigation_area: nav,
             linkable: child_page,
             position: 1,
             parent_id: parent_nav_item.id)
    end

    before do
      nav_items = nav.navigation_items.positioned.includes(:string_translations, linkable: %i[string_translations])
      helper.instance_variable_set(:@nav_item_children, nav_items.group_by(&:parent_id))
    end

    it 'returns true when child is the current page' do
      result = helper.has_active_descendants?(parent_nav_item.id, child_page)

      expect(result).to be true
    end

    it 'returns false when no descendants are active' do
      other_page = create(:better_together_page, slug: 'other')
      result = helper.has_active_descendants?(parent_nav_item.id, other_page)

      expect(result).to be false
    end

    it 'returns false when nav item has no children' do
      result = helper.has_active_descendants?(child_nav_item.id, parent_page)

      expect(result).to be false
    end

    it 'memoizes results for performance' do
      helper.has_active_descendants?(parent_nav_item.id, child_page)

      cache = helper.instance_variable_get(:@active_descendant_cache)
      expect(cache).to have_key(parent_nav_item.id)
    end

    it 'returns cached result on subsequent calls' do
      first_result = helper.has_active_descendants?(parent_nav_item.id, child_page)

      # This should use cached value
      second_result = helper.has_active_descendants?(parent_nav_item.id, child_page)

      expect(first_result).to eq(second_result)
    end
  end
end
