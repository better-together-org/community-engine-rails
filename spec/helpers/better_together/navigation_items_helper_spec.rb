# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::NavigationItemsHelper do
  let(:platform) { BetterTogether::Platform.find_or_create_by(host: true) { |p| p.assign_attributes(name: 'Test Platform', url: 'http://test.local', privacy: 'private') } }
  let(:navigation_area) { create(:better_together_navigation_area) }
  let(:navigation_items) do
    create_list(:better_together_navigation_item, 3, navigation_area:, parent: nil, visible: true, privacy: 'public')
  end

  before do
    helper.extend(BetterTogether::ApplicationHelper)
    allow(helper).to receive_messages(host_platform: platform, current_user: nil)
  end

  describe '#render_navigation_items_list' do
    subject(:rendered_output) do
      helper.render_navigation_items_list(
        navigation_items:,
        navigation_area:,
        **kwargs
      )
    end

    let(:kwargs) { {} }

    context 'with default parameters' do
      it 'renders navigation items list with default classes' do
        expect(rendered_output).to have_css('ul.navbar-nav')
        expect(rendered_output).to have_css('ul.flex-lg-row')
        expect(rendered_output).to have_css('ul.flex-wrap')
        expect(rendered_output).to have_css('ul.gap-2')
        expect(rendered_output).to have_css('ul.gap-md-3')
        expect(rendered_output).to have_css('ul.justify-content-center')
      end

      it 'includes navigation area DOM classes when provided' do
        expect(rendered_output).to have_css("ul.#{helper.dom_class(navigation_area, :nav_items)}")
      end

      it 'includes navigation area DOM ID when provided' do
        expect(rendered_output).to have_css("ul##{helper.dom_id(navigation_area, :nav_items)}")
      end

      it 'renders all navigation items' do
        navigation_items.each do |item|
          expect(rendered_output).to have_css('li', text: item.title)
        end
      end
    end

    context 'without navigation_area' do
      let(:rendered_output_no_area) do
        helper.render_navigation_items_list(navigation_items:)
      end

      it 'renders without navigation area DOM classes' do
        expect(rendered_output_no_area).to have_css('ul.navbar-nav')
        expect(rendered_output_no_area).not_to have_css('ul[class*="_nav_items"]')
      end

      it 'renders without navigation area DOM ID' do
        expect(rendered_output_no_area).to have_css('ul.navbar-nav')
        expect(rendered_output_no_area).not_to have_css('ul[id*="_nav_items"]')
      end

      it 'still renders public navigation items' do
        expect(rendered_output_no_area).to have_css('ul.navbar-nav')
        expect(rendered_output_no_area).to have_css('li', count: 3)
      end
    end

    context 'with custom justify parameter' do
      let(:kwargs) { { justify: 'start' } }

      it 'applies custom justify class' do
        expect(rendered_output).to have_css('ul.justify-content-start')
        expect(rendered_output).not_to have_css('ul.justify-content-center')
      end
    end

    context 'with custom base_class parameter' do
      let(:kwargs) { { base_class: 'custom-nav' } }

      it 'applies custom base class' do
        expect(rendered_output).to have_css('ul.custom-nav')
        expect(rendered_output).not_to have_css('ul.navbar-nav')
      end

      it 'preserves other default classes' do
        expect(rendered_output).to have_css('ul.flex-lg-row')
        expect(rendered_output).to have_css('ul.flex-wrap')
      end
    end

    context 'with custom flex_direction_class parameter' do
      let(:kwargs) { { flex_direction_class: 'flex-column' } }

      it 'applies custom flex direction class' do
        expect(rendered_output).to have_css('ul.flex-column')
        expect(rendered_output).not_to have_css('ul.flex-lg-row')
      end
    end

    context 'with custom flex_wrap_class parameter' do
      let(:kwargs) { { flex_wrap_class: 'flex-nowrap' } }

      it 'applies custom flex wrap class' do
        expect(rendered_output).to have_css('ul.flex-nowrap')
        expect(rendered_output).not_to have_css('ul.flex-wrap')
      end
    end

    context 'with custom gap_class parameter' do
      let(:kwargs) { { gap_class: 'gap-4' } }

      it 'applies custom gap class' do
        expect(rendered_output).to have_css('ul.gap-4')
        expect(rendered_output).not_to have_css('ul.gap-2')
      end
    end

    context 'with custom gap_md_class parameter' do
      let(:kwargs) { { gap_md_class: 'gap-md-5' } }

      it 'applies custom gap-md class' do
        expect(rendered_output).to have_css('ul.gap-md-5')
        expect(rendered_output).not_to have_css('ul.gap-md-3')
      end
    end

    context 'with multiple custom CSS parameters' do
      let(:kwargs) do
        {
          justify: 'end',
          base_class: 'footer-nav',
          flex_direction_class: 'flex-column',
          flex_wrap_class: 'flex-nowrap',
          gap_class: 'gap-5',
          gap_md_class: 'gap-md-4'
        }
      end

      it 'applies all custom classes' do
        expect(rendered_output).to have_css('ul.footer-nav')
        expect(rendered_output).to have_css('ul.flex-column')
        expect(rendered_output).to have_css('ul.flex-nowrap')
        expect(rendered_output).to have_css('ul.gap-5')
        expect(rendered_output).to have_css('ul.gap-md-4')
        expect(rendered_output).to have_css('ul.justify-content-end')
      end

      it 'does not apply default classes' do
        expect(rendered_output).not_to have_css('ul.navbar-nav')
        expect(rendered_output).not_to have_css('ul.flex-lg-row')
        expect(rendered_output).not_to have_css('ul.flex-wrap')
        expect(rendered_output).not_to have_css('ul.gap-2')
        expect(rendered_output).not_to have_css('ul.gap-md-3')
        expect(rendered_output).not_to have_css('ul.justify-content-center')
      end
    end

    context 'with nil CSS parameters' do
      let(:kwargs) do
        {
          flex_direction_class: nil,
          flex_wrap_class: nil,
          gap_class: nil,
          gap_md_class: nil
        }
      end

      it 'omits nil classes from output' do
        # Should still have base_class and justify
        expect(rendered_output).to have_css('ul.navbar-nav')
        expect(rendered_output).to have_css('ul.justify-content-center')

        # Should not have the nil classes
        expect(rendered_output).not_to match(/class="[^"]*\s{2,}[^"]*"/) # No double spaces
      end
    end

    context 'with empty navigation items' do
      let(:navigation_items) { [] }

      it 'renders empty ul element' do
        expect(rendered_output).to have_css('ul.navbar-nav')
        expect(rendered_output).not_to have_css('li')
      end
    end
  end

  describe '#render_better_together_nav_items' do
    let(:nav_area) { build_stubbed(:better_together_navigation_area, identifier: 'better-together') }
    let!(:nav_items) { build_stubbed_list(:better_together_navigation_item, 2, navigation_area: nav_area, parent: nil) }

    before do
      allow(helper).to receive_messages(better_together_nav_area: nav_area, better_together_nav_items: nav_items)
      allow(nav_area).to receive(:navigation_items).and_return(nav_items)
    end

    it 'uses render_navigation_items_list with default parameters' do
      expect(helper).to receive(:render_navigation_items_list).with(
        navigation_items: nav_items,
        navigation_area: nav_area
      ).and_call_original

      helper.render_better_together_nav_items
    end

    it 'caches the result' do
      cache_key = helper.cache_key_for_nav_area(nav_area)

      expect(Rails.cache).to receive(:fetch).with(cache_key).and_call_original
      helper.render_better_together_nav_items
    end
  end

  describe '#render_platform_host_nav_items' do
    let(:nav_area) { build_stubbed(:better_together_navigation_area, identifier: 'platform-host') }
    let!(:nav_items) { build_stubbed_list(:better_together_navigation_item, 2, navigation_area: nav_area, parent: nil) }

    before do
      allow(helper).to receive_messages(platform_host_nav_area: nav_area, platform_host_nav_items: nav_items)
      allow(nav_area).to receive(:navigation_items).and_return(nav_items)
    end

    it 'uses render_navigation_items_list with default parameters' do
      expect(helper).to receive(:render_navigation_items_list).with(
        navigation_items: nav_items,
        navigation_area: nav_area
      ).and_call_original

      helper.render_platform_host_nav_items
    end
  end

  describe '#render_platform_footer_nav_items' do
    let(:nav_area) { build_stubbed(:better_together_navigation_area, identifier: 'platform-footer') }
    let!(:nav_items) { build_stubbed_list(:better_together_navigation_item, 2, navigation_area: nav_area, parent: nil) }

    before do
      allow(helper).to receive_messages(platform_footer_nav_area: nav_area, platform_footer_nav_items: nav_items)
      allow(nav_area).to receive(:navigation_items).and_return(nav_items)
    end

    it 'uses render_navigation_items_list with default parameters' do
      expect(helper).to receive(:render_navigation_items_list).with(
        navigation_items: nav_items,
        navigation_area: nav_area
      ).and_call_original

      helper.render_platform_footer_nav_items
    end
  end

  describe '#render_platform_header_nav_items' do
    let(:nav_area) { build_stubbed(:better_together_navigation_area, identifier: 'platform-header') }
    let!(:nav_items) { build_stubbed_list(:better_together_navigation_item, 2, navigation_area: nav_area, parent: nil) }

    before do
      allow(helper).to receive_messages(platform_header_nav_area: nav_area, platform_header_nav_items: nav_items)
      allow(nav_area).to receive(:navigation_items).and_return(nav_items)
    end

    it 'uses render_navigation_items_list with default parameters' do
      expect(helper).to receive(:render_navigation_items_list).with(
        navigation_items: nav_items,
        navigation_area: nav_area
      ).and_call_original

      helper.render_platform_header_nav_items
    end
  end
end
