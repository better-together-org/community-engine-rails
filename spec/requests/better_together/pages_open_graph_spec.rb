# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Static page share metadata', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:page) do
    slug = "og-page-#{SecureRandom.hex(4)}"
    create(:better_together_page, slug:, identifier: slug, protected: false, meta_description: 'A tidy description',
                                  published_at: 1.day.ago, privacy: 'public')
  end

  before do
    page.page_blocks.create!(block: create(:content_markdown, markdown_source: '## Hello'), position: 0)
  end

  it 'renders one clean og:url and trimmed og/description attributes' do
    get better_together.render_page_path(path: page.slug, locale:)
    doc = Nokogiri::HTML(response.body)
    og_url = doc.at_css("meta[property='og:url']")['content']

    expect(og_url).to match(%r{\Ahttps?://\S+/#{page.slug}\z})
    expect(og_url.scan('http').size).to eq(1)
    %w[og:title og:description].each do |property|
      value = doc.at_css("meta[property='#{property}']")['content']
      expect(value).to eq(value.squish)
    end
    expect(doc.at_css("meta[name='description']")['content']).to eq('A tidy description')
    expect(doc.at_css("meta[property='og:type']")['content']).to eq('website')
    expect(response.body).not_to include('twitter:')
  end

  describe 'og:image' do
    let(:png) { 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' }
    let(:hero) { create(:better_together_content_hero, :with_background_image) }

    let(:share_image_content) { ->(doc) { doc.at_css("meta[property='og:image']")&.[]('content').to_s } }

    it 'uses the feature image, ahead of the hero background', :aggregate_failures do
      page.page_blocks.create!(block: hero, position: 1)
      page.reload.update!(feature_image_data: png, feature_image_filename: 'banner.png')

      get better_together.render_page_path(path: page.slug, locale:)

      expect(share_image_content.call(Nokogiri::HTML(response.body))).to include('banner.png')
      expect(Nokogiri::HTML(response.body).at_css("meta[property='og:image:alt']")['content']).to eq(page.title)
    end

    it 'falls back to the hero background for one release' do
      page.page_blocks.create!(block: hero, position: 1)

      get better_together.render_page_path(path: page.slug, locale:)

      expect(share_image_content.call(Nokogiri::HTML(response.body))).to include('hero_background.jpg')
    end

    it 'falls back to the platform logo when the page has neither' do
      get better_together.render_page_path(path: page.slug, locale:)

      expect(share_image_content.call(Nokogiri::HTML(response.body))).not_to include('banner.png', 'hero_background.jpg')
    end
  end
end
