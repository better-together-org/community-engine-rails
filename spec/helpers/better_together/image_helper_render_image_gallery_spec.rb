# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ImageHelper, '#render_image_gallery' do
  include described_class
  include BetterTogether::ApplicationHelper
  include ImageGalleryHelpers

  let(:root) { BetterTogether::Engine.root.join('app/assets/images/better_together') }
  let(:image) do
    build(:better_together_content_image, alt_text: 'A harbour at dusk', caption: 'Dusk', attribution: 'A. Photographer',
                                          attribution_url: 'https://example.com/a').tap do |record|
      record.media.attach(io: File.open(root.join('unsplash-community-1.jpeg')), filename: 'a.jpeg',
                          content_type: 'image/jpeg')
      record.save!
      record.media.blob.analyze
    end
  end
  let(:plain) do
    build(:better_together_content_image, alt_text: '', caption: '', attribution: '', attribution_url: '').tap do |record|
      record.media.attach(io: File.open(root.join('unsplash-community-2.jpeg')), filename: 'b.jpeg',
                          content_type: 'image/jpeg')
      record.save!
    end
  end

  before do
    configure_host_platform
    allow(self).to receive(:storage_proxy_url_for) { |attachment| "/proxy/#{attachment.class.name.demodulize}" }
  end

  def gallery(images, **)
    Capybara.string(render_image_gallery(images, 'Harbour', **))
  end

  it 'renders nothing without images' do
    expect(render_image_gallery([], 'Harbour')).to be_nil
  end

  it 'uses list semantics, a label and the grid layout by default', :aggregate_failures do
    html = gallery([image, plain])

    expect(html).to have_css('section.image-gallery.image-gallery--grid[aria-label="Harbour"]')
    expect(html).to have_css('ul.image-gallery__list > li.image-gallery__item', count: 2)
    expect(html).to have_no_css('[data-controller]')
  end

  it 'uses per-image alt text and falls back to the gallery name', :aggregate_failures do
    html = gallery([image, plain])

    expect(html).to have_css('img[alt="A harbour at dusk"]')
    expect(html).to have_css('img[alt="Harbour"]')
  end

  it 'adds figure, caption and linked attribution only when present', :aggregate_failures do
    html = gallery([image, plain])

    expect(html).to have_css('figure', count: 2)
    expect(html).to have_css('figcaption', count: 1, text: 'Dusk')
    expect(html).to have_css('figcaption a[href="https://example.com/a"]', text: 'A. Photographer')
  end

  it 'lazy loads and reserves space', :aggregate_failures do
    html = gallery([image])

    expect(html).to have_css('img[loading="lazy"][decoding="async"][width][height]')
    expect(html).to have_css('img[srcset][sizes="100vw"]')
  end

  it 'marks a single image so it spans the grid' do
    expect(gallery([image])).to have_css('li.image-gallery__item--single')
  end

  it 'attaches the masonry controller only when asked, on the list', :aggregate_failures do
    html = gallery([image, plain], layout: :masonry)

    expect(html).to have_css('section.image-gallery--masonry')
    expect(html).to have_css('ul[data-controller="better_together--masonry"]' \
                             '[data-better_together--masonry-item-selector-value=".image-gallery__item"]')
  end

  it 'falls back to the grid for an unknown layout' do
    expect(gallery([image], layout: :spiral)).to have_css('.image-gallery--grid')
  end

  it 'escapes caption markup' do
    image.reload.update!(caption: '<script>alert(1)</script>')

    expect(render_image_gallery([image], 'Harbour')).not_to include('<script>')
  end
end
