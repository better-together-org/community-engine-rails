# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Block attachments in rich text' do # rubocop:disable RSpec/DescribeClass
  let(:registry) { BetterTogether::ContentSecurity::AttachableRegistry }
  let(:original_scrubber) { ActionText::ContentHelper.scrubber }

  before do
    configure_host_platform
    original_scrubber
    registry.register('BetterTogether::Content::VideoBlock')
    ActionText::ContentHelper.scrubber = BetterTogether::ContentSecurity::VideoEmbedScrubber.new
  end

  after do
    registry.reset!
    ActionText::ContentHelper.scrubber = original_scrubber
  end

  def render_body(block)
    html = "<p>Intro</p>#{ActionText::Attachment.from_attachable(block).to_html}"
    post = create(:better_together_post, privacy: 'public', content: html)
    content = BetterTogether::ContentSecurity::RichTextAttachmentFilter.new(post.reload.content.body).call

    ApplicationController.render(inline: '<%= render_action_text_content(content) %>', locals: { content: })
  end

  it 'renders a public video as a privacy-enhanced iframe outside the engine controllers', :aggregate_failures do
    html = render_body(create(:content_video_block, privacy: 'public'))

    expect(html).to include('Intro', '<iframe', 'https://www.youtube-nocookie.com/embed/')
    expect(html).not_to include('https://www.youtube.com/embed/')
  end

  it 'holds a video block that is not public', :aggregate_failures do
    html = render_body(create(:content_video_block, privacy: 'private'))

    expect(html).not_to include('<iframe')
    expect(html).to include('attachment--held-review')
  end
end
