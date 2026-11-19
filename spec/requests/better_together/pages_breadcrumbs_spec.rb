# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Page breadcrumbs', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:area) { create(:better_together_navigation_area, visible: true) }

  def make_page(slug, title)
    create(:better_together_page, slug:, identifier: slug.tr('/', '-'), title:, protected: false,
                                  published_at: 1.day.ago, privacy: 'public').tap do |page|
      page.page_blocks.create!(block: create(:content_markdown, markdown_source: '## Body'), position: 0)
    end.reload
  end

  def nav_item(title:, parent: nil, linkable: nil, item_type: 'link')
    create(:better_together_navigation_item, navigation_area: area, title:, parent:, linkable:, item_type:,
                                             visible: true, privacy: 'public', protected: false,
                                             url: linkable ? nil : '#grouping', position: 1)
  end

  def crumbs(doc)
    doc.css('#breadcrumbs-list li').map { |li| li.text.squish }
  end

  context 'with a navigation hierarchy' do
    it 'renders Home, the dropdown heading, then the current page, with JSON-LD' do
      about = make_page('foray-about-us', 'About us')
      heading = nav_item(title: 'Who we are', item_type: 'dropdown')
      nav_item(title: 'About us', parent: heading, linkable: about)

      get better_together.render_page_path(path: about.slug, locale:)
      doc = Nokogiri::HTML(response.body)

      expect(crumbs(doc)).to eq([I18n.t('breadcrumbs.home'), 'Who we are', 'About us'])
      expect(doc.at_css('#breadcrumbs')['aria-label']).to eq(I18n.t('breadcrumbs.label'))
      expect(doc.at_css('#breadcrumbs-list li:last-child')['aria-current']).to eq('page')
      expect(doc.css('#breadcrumbs-list a').size).to eq(1)

      data = JSON.parse(doc.at_css('#breadcrumbs-json-ld').text)
      expect(data['@type']).to eq('BreadcrumbList')
      expect(data['itemListElement'].map { |item| item['position'] }).to eq([1, 2])
      expect(data['itemListElement'].last['item']).to include('foray-about-us')
    end
  end

  context 'without navigation entries' do
    it 'shows Home then the page for a page outside any navigation tree' do
      lone = make_page('foray-lonely', 'Lonely page')

      get better_together.render_page_path(path: lone.slug, locale:)
      doc = Nokogiri::HTML(response.body)

      expect(crumbs(doc)).to eq([I18n.t('breadcrumbs.home'), 'Lonely page'])
    end

    it 'renders no breadcrumbs on the home page' do
      home = BetterTogether::Page.i18n.find_by(slug: 'home') || make_page('home', 'Home page')

      get better_together.render_page_path(path: home.slug, locale:)

      expect(response.body).not_to include('id="breadcrumbs"')
    end
  end
end
