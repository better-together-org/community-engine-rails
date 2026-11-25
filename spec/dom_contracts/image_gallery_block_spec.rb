# frozen_string_literal: true

require 'rails_helper'

# Stable hooks that the image gallery block screenshots and styles rely on.
RSpec.describe 'Image gallery block DOM contract', type: :request do
  let(:token) { SecureRandom.hex(4) }
  let(:images) do
    %w[unsplash-community-1.jpeg unsplash-community-2.jpeg].each_with_index.map do |file, index|
      create(:better_together_content_image, identifier: "gallery-dom-#{token}-#{index}", privacy: 'public',
                                             alt_text: "Dom view #{index}").tap do |image|
        image.media.attach(io: File.open(BetterTogether::Engine.root.join("app/assets/images/better_together/#{file}")),
                           filename: file, content_type: 'image/jpeg')
        image.media.blob.analyze
      end
    end
  end
  let(:page_record) do
    create(:better_together_page, privacy: 'public', published_at: 1.day.ago, slug: "gallery-block-#{token}").tap do |record|
      block = create(:content_image_gallery_block, image_ids: images.map(&:id).to_json, heading_en: "Photos #{token}")
      record.page_blocks.create!(block:, position: 0)
    end
  end

  before { configure_host_platform }

  it 'exposes the heading, gallery list, items and lightbox hooks', :aggregate_failures do
    get better_together.render_page_path(path: page_record.slug, locale: I18n.default_locale)

    page = Capybara.string(response.body)
    expect(page).to have_css('.image-gallery-block .image-gallery-block__heading', text: "Photos #{token}")
    expect(page).to have_css('.image-gallery-block .image-gallery__list .image-gallery__item', count: 2)
    expect(page).to have_css('.image-gallery[data-controller="better_together--lightbox"] .image-gallery__modal')
  end
end
