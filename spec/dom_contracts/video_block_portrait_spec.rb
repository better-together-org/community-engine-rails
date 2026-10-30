# frozen_string_literal: true

require 'rails_helper'

# Stable hooks that the portrait video screenshots and styles rely on.
RSpec.describe 'Portrait video block DOM contract', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:page_record) do
    create(:better_together_page, title: 'Vertical video', slug: 'vertical-video', identifier: 'vertical-video',
                                  privacy: 'public', published_at: 1.day.ago, protected: false)
  end

  before do
    configure_host_platform
    block = create(:content_video_block, aspect_ratio: '9x16')
    page_record.page_blocks.create!(block:, position: 0)
  end

  it 'wraps a vertical video in the portrait figure and 9x16 ratio', :aggregate_failures do
    get "/#{locale}/#{page_record.slug}"

    expect(response.body).to include('iframe-block iframe-block--portrait', 'ratio ratio-9x16')
  end

  it 'offers the vertical ratio in the block editor', :aggregate_failures do
    login('manager@example.test', 'SecureTest123!@#')
    get better_together.new_content_block_path(locale:, block_type: 'BetterTogether::Content::VideoBlock')

    expect(response.body).to include('video-block-aspect-ratio', 'value="9x16"')
  end
end
