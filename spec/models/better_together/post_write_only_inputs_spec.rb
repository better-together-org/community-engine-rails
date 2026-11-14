# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Post, '#write_only_inputs' do
  let(:registry) { BetterTogether::ContentSecurity::AttachableRegistry }
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, host: true) }
  let(:person) { create(:better_together_person) }
  let(:png) do
    Base64.strict_decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
  end
  let(:data) { Base64.strict_encode64(png) }
  let(:image_block) do
    BetterTogether::Content::Image.create!(platform:, privacy: 'public', identifier: "pai-#{SecureRandom.hex(3)}",
                                           creator: person, caption: 'Harbour', media_data: data,
                                           media_filename: 'harbour.png')
  end
  let(:video_block) { create(:content_video_block, platform:, privacy: 'public') }

  before do
    [BetterTogether::Content::Image, BetterTogether::Content::VideoBlock].each do |klass|
      klass.include(BetterTogether::Content::AttachableBlock) if defined?(BetterTogether::Content::AttachableBlock)
      klass.include(ActionText::Attachable)
    end
    registry.register('BetterTogether::Content::Image', 'BetterTogether::Content::VideoBlock')
  end

  after { registry.reset! }

  def build_post(**attrs)
    build(:better_together_post, platform:, content: 'Body text', **attrs)
  end

  def attached_ids(record)
    described_class.find(record.id).content.body.attachables.map(&:id)
  end

  describe 'cover_image_data' do
    it 'attaches the decoded image and clears the input', :aggregate_failures do
      post = build_post(cover_image_data: data, cover_image_filename: 'dawn.png')

      expect(post.save).to be(true)
      expect(post.cover_image).to be_attached
      expect(post.cover_image.filename.to_s).to eq('dawn.png')
      expect(post.cover_image_data).to be_nil
    end

    it 'rejects data that is not an image', :aggregate_failures do
      post = build_post(cover_image_data: Base64.strict_encode64('not an image'))

      expect(post).not_to be_valid
      expect(post.errors).to include(:cover_image_data)
    end
  end

  describe 'video_block_id' do
    it 'features the video ahead of attachment_block_ids on create' do
      post = build_post(video_block_id: video_block.id, attachment_block_ids: [image_block.id])
      post.save!

      expect(attached_ids(post)).to eq([video_block.id, image_block.id])
    end

    it 'is invalid for an unknown block', :aggregate_failures do
      post = build_post(video_block_id: SecureRandom.uuid)

      expect(post).not_to be_valid
      expect(post.errors).to include(:video_block_id)
      expect(post.errors).not_to include(:attachment_block_ids)
    end

    it 'is ignored on update', :aggregate_failures do
      post = build_post.tap(&:save!)
      post.update!(video_block_id: video_block.id, content: 'Edited')

      expect(attached_ids(post)).to be_empty
    end
  end
end
