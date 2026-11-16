# frozen_string_literal: true

require 'rails_helper'

# Stable ids on the page show view: the feature image banner and the title block.
RSpec.describe 'Page show title rule DOM contract', :as_platform_manager, type: :request do
  let(:png) { 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' }
  let(:page_record) do
    create(:better_together_page, title: 'Contract Page', slug: 'aaa-contract-page', identifier: 'aaa-contract-page',
                                  protected: false, published_at: 1.day.ago)
  end
  let(:doc) do
    page_record.page_blocks.create!(block: create(:content_markdown, markdown_source: '## Body'), position: 0)
    get better_together.page_path(page_record.slug, locale: I18n.default_locale)
    Nokogiri::HTML(response.body)
  end

  it 'renders the plain title block without a banner', :aggregate_failures do
    expect(doc.at_css('#page-title-block h1.page-title')).to be_present
    expect(doc.at_css('#page-feature-image')).to be_nil
  end

  it 'renders the banner with its image and title when the page has a feature image', :aggregate_failures do
    page_record.update!(feature_image_data: png, feature_image_filename: 'contract.png')

    expect(doc.at_css('figure#page-feature-image img#page-feature-image-img')).to be_present
    expect(doc.at_css('figure#page-feature-image figcaption#page-feature-image-title h1.page-title')).to be_present
    expect(doc.at_css('#page-title-block')).to be_nil
  end
end
