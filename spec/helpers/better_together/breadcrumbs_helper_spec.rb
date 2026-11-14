# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BreadcrumbsHelper do
  let(:crumb) { described_class::Crumb }

  before { helper.singleton_class.send(:define_method, :base_url) { 'https://example.test' } }

  describe '#breadcrumb_list_json_ld' do
    it 'numbers linked entries, makes URLs absolute and uses the current URL for the last entry' do
      trail = [crumb.new(title: 'Home', url: '/en'), crumb.new(title: 'Group', url: nil),
               crumb.new(title: 'Page', url: nil)]
      data = helper.breadcrumb_list_json_ld(trail, current_url: 'https://example.test/en/page')

      expect(data['@type']).to eq('BreadcrumbList')
      expect(data['itemListElement']).to eq(
        [{ '@type' => 'ListItem', 'position' => 1, 'name' => 'Home', 'item' => 'https://example.test/en' },
         { '@type' => 'ListItem', 'position' => 2, 'name' => 'Page', 'item' => 'https://example.test/en/page' }]
      )
    end
  end

  describe '#breadcrumb_trail_cache_key' do
    it 'changes when a title changes' do
      page = build_stubbed(:better_together_page)
      allow(helper).to receive(:breadcrumb_trail_for).and_return([crumb.new(title: 'A', url: '/a')],
                                                                 [crumb.new(title: 'B', url: '/a')])

      expect(helper.breadcrumb_trail_cache_key(page)).not_to eq(helper.breadcrumb_trail_cache_key(page))
    end
  end
end
