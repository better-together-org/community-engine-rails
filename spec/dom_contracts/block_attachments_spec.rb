# frozen_string_literal: true

require 'rails_helper'

# Stable hooks that the block attachment screenshots and styles rely on.
RSpec.describe 'Block attachments DOM contract', type: :request do
  include RequestSpecHelper

  let(:registry) { BetterTogether::ContentSecurity::AttachableRegistry }
  let(:original_scrubber) { ActionText::ContentHelper.scrubber }
  let(:png) do
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  end
  let(:video) { create(:content_video_block, privacy: 'public', aspect_ratio: '9x16') }
  let(:image) do
    BetterTogether::Content::Image.create!(platform: BetterTogether::Platform.find_by(host: true), privacy: 'public',
                                           identifier: 'dom-att-img', creator: create(:better_together_person),
                                           media_data: png, media_filename: 'h.png', caption: 'Harbour',
                                           attribution: 'A. Photographer')
  end
  let(:post_record) do
    html = [image, video].map { |block| ActionText::Attachment.from_attachable(block).to_html }.join
    create(:better_together_post, privacy: 'public', published_at: 1.day.ago, content: "<p>Intro</p>#{html}")
  end

  before do
    configure_host_platform
    original_scrubber
    registry.register('BetterTogether::Content::Image', 'BetterTogether::Content::VideoBlock')
    ActionText::ContentHelper.scrubber = BetterTogether::ContentSecurity::VideoEmbedScrubber.new
  end

  after do
    registry.reset!
    ActionText::ContentHelper.scrubber = original_scrubber
  end

  it 'gives each attached block a stable class hook', :aggregate_failures do
    get better_together.post_path(post_record, locale: I18n.default_locale)

    page = Capybara.string(response.body)

    expect(page).to have_css('.post-content figure.attached-image figcaption', text: 'Harbour')
    expect(page).to have_css('.post-content .attached-video--portrait .iframe-block--portrait')
  end
end
