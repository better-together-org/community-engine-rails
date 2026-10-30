# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::AttachableBlock do
  let(:png) do
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  end
  let(:video) { create(:content_video_block, privacy: 'public') }
  let(:image) do
    BetterTogether::Content::Image.create!(platform: configure_host_platform, privacy: 'public', identifier: 'ab-img',
                                           creator: create(:better_together_person), media_data: png,
                                           media_filename: 'h.png', caption: 'Harbour')
  end

  it 'gives a video block its own partials and plain text', :aggregate_failures do
    expect(video.to_attachable_partial_path).to eq('better_together/content/attachments/video_block')
    expect(video.to_trix_content_attachment_partial_path).to eq('better_together/content/attachments/video_block_trix')
    expect(video.attachable_plain_text_representation).to eq('[Video]')
  end

  it 'gives an image block its own partials and uses the caption as plain text', :aggregate_failures do
    expect(image.to_attachable_partial_path).to eq('better_together/content/attachments/image')
    expect(image.to_trix_content_attachment_partial_path).to eq('better_together/content/attachments/image_trix')
    expect(image.attachable_plain_text_representation).to eq('Harbour')
  end

  it 'round-trips a block through its signed global id', :aggregate_failures do
    [video, image].each do |block|
      html = ActionText::Attachment.from_attachable(block).to_html
      attachables = ActionText::Content.new(html).attachables

      expect(attachables).to eq([block])
    end
  end
end
