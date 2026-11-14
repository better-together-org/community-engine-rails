# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/_image_gallery_block' do
  let(:images) do
    %w[unsplash-community-1.jpeg unsplash-community-2.jpeg].each_with_index.map do |file, index|
      create(:better_together_content_image, identifier: "gallery-view-#{SecureRandom.hex(4)}",
                                             alt_text: "View <i>#{index}</i>", caption: "Caption #{index}").tap do |image|
        image.media.attach(io: File.open(BetterTogether::Engine.root.join("app/assets/images/better_together/#{file}")),
                           filename: file, content_type: 'image/jpeg')
        image.media.blob.analyze
      end
    end
  end
  let(:block) do
    create(:content_image_gallery_block, image_ids: images.map(&:id).to_json, heading_en: 'Field <b>photos</b>')
  end
  let(:allowed) { true }

  before do
    configure_host_platform
    view.extend(BetterTogether::ImageHelper)
    view.define_singleton_method(:content_actions_visible_for?) { |_block| false }
    without_partial_double_verification do
      allow(view).to receive(:policy).and_return(instance_double(BetterTogether::Content::BlockPolicy, show?: allowed))
    end
  end

  def render_block(record)
    render partial: 'better_together/content/blocks/image_gallery_block',
           locals: { image_gallery_block: record }
  end

  it 'renders the images in order with a lightbox by default', :aggregate_failures do
    render_block(block)

    expect(rendered).to have_css('.image-gallery-block .image-gallery__item', count: 2)
    expect(rendered).to have_css('.image-gallery__open', count: 2)
    expect(rendered).to have_css('.image-gallery-block__heading', text: 'Field <b>photos</b>')
  end

  it 'escapes user content', :aggregate_failures do
    render_block(block)

    expect(rendered).not_to include('<b>photos</b>')
    expect(rendered).not_to include('<i>0</i>')
  end

  it 'omits the viewer when the lightbox is off' do
    block.update!(lightbox: 'false')
    render_block(block)

    expect(rendered).to have_no_css('.image-gallery__open')
  end

  it 'uses the masonry layout when configured' do
    block.update!(layout: 'masonry')
    render_block(block)

    expect(rendered).to have_css('.image-gallery--masonry')
  end

  it 'shows the empty state without images' do
    render_block(create(:content_image_gallery_block))

    expect(rendered).to have_css('.image-gallery-block__empty', text: 'No images to display.')
  end

  context 'when the viewer may not see the images' do
    let(:allowed) { false }

    it 'shows the empty state' do
      render_block(block)

      expect(rendered).to have_css('.image-gallery-block__empty')
    end
  end

  describe 'fields partial' do
    before do
      view.define_singleton_method(:resource_search_content_blocks_path) { |**| '/search' }
      view.define_singleton_method(:translation_tab_button) { |**_args| ''.html_safe }
      view.define_singleton_method(:temp_id_for) { |_b, temp_id:| temp_id }
    end

    it 'pre-populates the saved values', :aggregate_failures do
      render partial: 'better_together/content/blocks/fields/image_gallery_block',
             locals: { block:, scope: 'block', temp_id: 'x' }

      expect(rendered).to have_css('select[multiple] option[selected]', count: 2)
      expect(rendered).to have_css('select[name="block[layout]"] option[selected][value="grid"]')
      expect(rendered).to have_checked_field('block[lightbox]')
    end
  end
end
