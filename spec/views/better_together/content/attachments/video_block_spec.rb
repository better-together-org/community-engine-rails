# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/attachments/video_block' do # rubocop:disable RSpec/DescribeClass
  before { configure_host_platform }

  it 'embeds a youtube video through the privacy-enhanced host', :aggregate_failures do
    video_block = create(:content_video_block, privacy: 'public')

    render partial: 'better_together/content/attachments/video_block', locals: { video_block: }

    page = Capybara.string(rendered)
    expect(page).to have_css('.attached-video.attached-video--landscape')
    expect(rendered).to include('https://www.youtube-nocookie.com/embed/')
  end

  it 'marks a vertical video as portrait' do
    video_block = create(:content_video_block, privacy: 'public', aspect_ratio: '9x16')

    render partial: 'better_together/content/attachments/video_block', locals: { video_block: }

    expect(Capybara.string(rendered)).to have_css('.attached-video--portrait .iframe-block--portrait')
  end

  it 'shows a short preview inside the editor' do
    video_block = create(:content_video_block, privacy: 'public')

    render partial: 'better_together/content/attachments/video_block_trix', locals: { video_block: }

    expect(Capybara.string(rendered)).to have_css('.video-embed-preview', text: video_block.video_url)
  end
end
