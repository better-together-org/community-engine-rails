# frozen_string_literal: true

require 'rails_helper'

# Stable hooks that the gallery styles, screenshots and lightbox rely on.
RSpec.describe 'Image gallery DOM contract', type: :request do
  include ImageGalleryHelpers

  before { configure_host_platform }

  it 'renders the grid gallery with figures, captions and lazy images', :aggregate_failures do
    page_record = build_gallery_page
    get better_together.render_page_path(path: page_record.slug, locale: I18n.default_locale, **gallery_params)

    page = Capybara.string(response.body)
    expect(page).to have_css('section.image-gallery.image-gallery--grid ul.image-gallery__list')
    expect(page).to have_css('li.image-gallery__item figure.image-gallery__figure', count: 4)
    expect(page).to have_css('img.image-gallery__image[loading="lazy"][alt="Harbour view 1"]')
    expect(page).to have_css('figcaption.image-gallery__caption', text: 'Harbour caption 1')
  end

  it 'renders the opt-in masonry layout', :aggregate_failures do
    page_record = build_gallery_page
    get better_together.render_page_path(path: page_record.slug, locale: I18n.default_locale,
                                         **gallery_params('masonry'))

    page = Capybara.string(response.body)
    expect(page).to have_css('section.image-gallery--masonry [data-controller="better_together--masonry"]')
  end
end
