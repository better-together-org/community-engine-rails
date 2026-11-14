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
end
