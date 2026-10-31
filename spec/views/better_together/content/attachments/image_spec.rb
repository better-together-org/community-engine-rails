# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/attachments/image' do # rubocop:disable RSpec/DescribeClass
  let(:png) do
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  end

  def build_image(**attrs)
    BetterTogether::Content::Image.create!(
      { platform: configure_host_platform, privacy: 'public', identifier: "att-#{SecureRandom.hex(3)}",
        creator: create(:better_together_person), media_data: png, media_filename: 'h.png',
        caption: 'Harbour' }.merge(attrs)
    )
  end

  it 'renders the caption and a same-origin storage path', :aggregate_failures do
    image = build_image

    render partial: 'better_together/content/attachments/image', locals: { image: }

    page = Capybara.string(rendered)
    expect(page).to have_css('figure.attached-image figcaption', text: 'Harbour')
    expect(page.find('img')[:src]).to start_with('/rails/active_storage/')
  end

  it 'links a photo credit that has a url', :aggregate_failures do
    image = build_image(attribution: 'A. Photographer', attribution_url: 'https://example.test/credit')

    render partial: 'better_together/content/attachments/image', locals: { image: }

    expect(Capybara.string(rendered))
      .to have_css('.attached-image__attribution a[rel="noopener noreferrer"]', text: 'A. Photographer')
  end

  it 'shows a short preview inside the editor' do
    image = build_image

    render partial: 'better_together/content/attachments/image_trix', locals: { image: }

    expect(Capybara.string(rendered)).to have_css('.image-embed-preview', text: 'Harbour')
  end
end
