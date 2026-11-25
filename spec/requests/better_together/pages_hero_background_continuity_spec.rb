# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261115210000_copy_hero_backgrounds_to_page_feature_image')

# Depends on CopyHeroBackgroundsToPageFeatureImage from the feature image PR: a page whose hero has a
# background image keeps that image after the hero rendering path is removed, and shows it once.
RSpec.describe 'Hero background continuity', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:png) { 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' }
  let(:page_record) do
    create(:better_together_page, title: 'Continuity', slug: 'aaa-continuity', identifier: 'aaa-continuity',
                                  protected: false, published_at: 1.day.ago, privacy: 'public')
  end
  let(:hero) { create(:better_together_content_hero, :with_background_image, privacy: 'public') }
  let(:run_migration) { -> { ActiveRecord::Migration.suppress_messages { CopyHeroBackgroundsToPageFeatureImage.new.up } } }
  let(:doc) do
    get better_together.page_path(page_record.slug, locale:)
    Nokogiri::HTML(response.body)
  end
  let(:body_html) { doc.at_css('body').to_html }
  let(:share_image) { -> { doc.at_css("meta[property='og:image']")['content'] } }

  before do
    page_record.page_blocks.create!(block: hero, position: 0)
    page_record.page_blocks.create!(block: create(:content_markdown, markdown_source: '## Body'), position: 1)
    page_record.reload
  end

  it 'keeps the hero image as the feature image and link preview after the migration', :aggregate_failures do
    run_migration.call

    expect(page_record.reload.feature_image).to be_attached
    expect(page_record.feature_image.blob).to eq(hero.background_image_file.blob)
    expect(share_image.call).to include(page_record.feature_image.filename.to_s)
  end

  it 'shows the image once: the hero keeps it and the banner is suppressed', :aggregate_failures do
    run_migration.call

    expect(doc.at_css('#page-feature-image')).to be_nil
    expect(body_html.scan('hero_background.jpg').size).to eq(1)
    expect(doc.at_css('h1.hero-heading')).to be_present
    expect(doc.at_css('h1.page-title')).to be_nil
  end

  it 'shows the banner and a plain title when the hero is not first but shares the image', :aggregate_failures do
    page_record.page_blocks.find_by(block: hero).update!(position: 5)
    run_migration.call

    expect(doc.at_css('#page-feature-image')).to be_nil
    expect(doc.css('h1.page-title').map(&:text)).to eq(['Continuity'])
  end

  it 'draws both images when the page feature image differs from the hero background', :aggregate_failures do
    page_record.update!(feature_image_data: png, feature_image_filename: 'own.png')

    expect(doc.at_css('#page-feature-image img#page-feature-image-img')).to be_present
    expect(body_html.scan('hero_background.jpg').size).to eq(1)
  end

  it 'shows the banner when the hero that shared the image is deleted', :aggregate_failures do
    run_migration.call
    page_record.page_blocks.find_by(block: hero).destroy!
    page_record.reload

    expect(doc.at_css('#page-feature-image img')).to be_present
    expect(share_image.call).to include('hero_background.jpg')
  end
end
