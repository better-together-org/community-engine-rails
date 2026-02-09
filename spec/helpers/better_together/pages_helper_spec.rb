# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PagesHelper do
  before do
    configure_host_platform
    # Stub current_user to avoid Devise/Warden setup
    allow(helper).to receive(:current_user).and_return(nil)
  end

  describe '#page_show_cache_key' do
    let(:page) { create(:better_together_page) }

    it 'includes page attributes in cache key' do
      cache_key = helper.page_show_cache_key(page)

      expect(cache_key).to include('page-show')
      expect(cache_key).to include(page.id)
      expect(cache_key).to include(page.updated_at)
      expect(cache_key).to include(I18n.locale)
    end

    context 'when page has sidebar_nav' do
      let(:community) { BetterTogether::Platform.host.first.community }
      let(:nav) { create(:better_together_navigation_area, navigable: community) }
      let!(:page_with_sidebar) do
        create(:better_together_page, sidebar_nav: nav, protected: false)
      end
      let!(:nav_item) do
        create(:better_together_navigation_item,
               navigation_area: nav,
               linkable: page_with_sidebar,
               position: 1)
      end

      it 'includes sidebar_nav cache key' do
        initial_cache_key = helper.page_show_cache_key(page_with_sidebar)

        expect(initial_cache_key).to include(nav.cache_key_with_version)
      end

      it 'changes when navigation item linkable is updated' do
        initial_cache_key = helper.page_show_cache_key(page_with_sidebar)

        # Update the navigation item's linkable (creates a new page and assigns it)
        new_page = create(:better_together_page, protected: false)
        nav_item.update!(linkable: new_page)

        # Reload to get fresh cache key
        nav.reload
        new_cache_key = helper.page_show_cache_key(page_with_sidebar)

        expect(new_cache_key).not_to eq(initial_cache_key)
      end

      it 'changes when page title is updated through navigation items' do
        initial_cache_key = helper.page_show_cache_key(page_with_sidebar)

        # Update the page's title, which should touch navigation_items -> navigation_area
        page_with_sidebar.update!(title: 'Updated Title')

        # Reload to get fresh cache key
        nav.reload
        new_cache_key = helper.page_show_cache_key(page_with_sidebar)

        expect(new_cache_key).not_to eq(initial_cache_key)
      end
    end

    context 'when page has no sidebar_nav' do
      it 'handles nil sidebar_nav gracefully' do
        cache_key = helper.page_show_cache_key(page)

        expect(cache_key).to include('page-show')
        expect(cache_key).to include(nil) # sidebar_nav&.cache_key_with_version returns nil
      end
    end
  end
end
