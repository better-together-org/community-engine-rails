# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ApplicationHelper, '#open_graph_meta_tags' do
  before { configure_host_platform }

  def meta_content(html, property)
    Nokogiri::HTML.fragment(html).at_css("meta[property='#{property}']")&.[]('content')
  end

  describe 'Open Graph tags' do
    it 'emits a single clean og:url when the view captured it with surrounding whitespace' do
      helper.content_for(:og_url, "\n    https://example.test/en/about\n  ")

      expect(meta_content(helper.open_graph_meta_tags, 'og:url')).to eq("#{helper.base_url}/en/about")
    end

    it 'strips whitespace from og:title and og:description' do
      helper.content_for(:og_title, "\n  About us | Site\n")
      helper.content_for(:og_description, "\n    A short\n    description.\n")
      html = helper.open_graph_meta_tags

      expect(meta_content(html, 'og:title')).to eq('About us | Site')
      expect(meta_content(html, 'og:description')).to eq('A short description.')
    end

    it 'defaults og:type to website and honours an allowed override' do
      expect(meta_content(helper.open_graph_meta_tags, 'og:type')).to eq('website')

      helper.content_for(:og_type, "\n article \n")
      expect(meta_content(helper.open_graph_meta_tags, 'og:type')).to eq('article')
    end

    it 'ignores an unknown og:type' do
      helper.content_for(:og_type, 'video.movie')

      expect(meta_content(helper.open_graph_meta_tags, 'og:type')).to eq('website')
    end

    it 'emits an absolute og:image with width, height and alt, and never twitter tags' do
      helper.content_for(:og_image, '/media/share.png')
      helper.content_for(:og_image_width, "\n 1200\n")
      helper.content_for(:og_image_height, '630')
      helper.content_for(:og_image_alt, "\n A foray table \n")
      html = helper.open_graph_meta_tags

      expect(meta_content(html, 'og:image')).to eq("#{helper.request.base_url}/media/share.png")
      expect(meta_content(html, 'og:image:width')).to eq('1200')
      expect(meta_content(html, 'og:image:height')).to eq('630')
      expect(meta_content(html, 'og:image:alt')).to eq('A foray table')
      expect(html).not_to include('twitter:')
    end
  end

  describe '#seo_meta_tags' do
    it 'squishes the meta description and keywords' do
      helper.content_for(:meta_description, "\n   Hello\n   world \n")
      helper.content_for(:meta_keywords, "\n a, b \n")
      doc = Nokogiri::HTML.fragment(helper.seo_meta_tags)

      expect(doc.at_css("meta[name='description']")['content']).to eq('Hello world')
      expect(doc.at_css("meta[name='keywords']")['content']).to eq('a, b')
    end
  end

  describe '#canonical_link_tag' do
    it 'uses a per-view canonical URL override' do
      helper.content_for(:canonical_url, "\n https://example.test/en/primary \n")

      expect(Nokogiri::HTML.fragment(helper.canonical_link_tag).at_css('link')['href'])
        .to eq('https://example.test/en/primary')
    end
  end

  describe '#og_image_dimensions' do
    it 'reads width and height from blob metadata' do
      attachment = Struct.new(:blob).new(Struct.new(:metadata).new({ 'width' => 800, 'height' => 600 }))

      expect(helper.og_image_dimensions(attachment)).to eq(width: '800', height: '600')
    end

    it 'returns nothing for an unanalysed blob' do
      attachment = Struct.new(:blob).new(Struct.new(:metadata).new({}))

      expect(helper.og_image_dimensions(attachment)).to eq({})
    end
  end
end
