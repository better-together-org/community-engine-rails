# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'image gallery lightbox', :accessibility, :js, retry: 0 do
  include ImageGalleryHelpers

  before do
    configure_host_platform
    page_record = build_gallery_page
    visit better_together.render_page_path(path: page_record.slug, locale: I18n.default_locale,
                                           **gallery_params('grid', lightbox: true))
  end

  def open_first
    expect(page).to have_css('.image-gallery__open', count: 4)
    first('.image-gallery__open').click
    expect(page).to have_css('.image-gallery__modal.show')
  end

  it 'opens the first image with a counter and caption', :aggregate_failures do
    open_first

    expect(page).to have_css('.image-gallery__counter', text: '1 of 4')
    expect(page).to have_css('.image-gallery__modal-caption', text: 'Harbour caption 1')
    expect(find('.image-gallery__modal-image')[:alt]).to eq('Harbour view 1')
  end

  it 'moves with the arrow keys and wraps around', :aggregate_failures do
    open_first
    find('.image-gallery__modal').send_keys(:arrow_right)
    expect(page).to have_css('.image-gallery__counter', text: '2 of 4')

    find('.image-gallery__modal').send_keys(:arrow_left, :arrow_left)
    expect(page).to have_css('.image-gallery__counter', text: '4 of 4')
  end

  it 'moves with the buttons' do
    open_first
    find('.image-gallery__next').click
    expect(page).to have_css('.image-gallery__counter', text: '2 of 4')
  end

  it 'closes with Escape and returns focus to the thumbnail', :aggregate_failures do
    open_first
    sleep 0.6 # Bootstrap ignores hide while the fade-in transition is running
    find('.image-gallery__modal').send_keys(:escape)

    expect(page).to have_no_css('.image-gallery__modal.show')
    expect(page).to have_css('.image-gallery__open:focus')
  end

  it 'has no axe violations with the viewer open' do
    open_first

    expect(page).to be_axe_clean.within('.image-gallery__modal')
  end

  it 'has no axe violations in the closed gallery' do
    expect(page).to be_axe_clean.within('.image-gallery')
  end
end
