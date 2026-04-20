# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe VideoBlock do
      subject(:block) { described_class.new(video_url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ') }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is not content_addable pending deferred rollout review' do
        expect(described_class.content_addable?).to be false
      end

      describe 'defaults' do
        it 'defaults aspect_ratio to 16x9' do
          expect(described_class.new.aspect_ratio).to eq('16x9')
        end
      end

      describe 'validations' do
        it 'requires video_url' do
          block.video_url = ''
          block.valid?
          expect(block.errors[:video_url]).not_to be_empty
        end

        it 'validates aspect_ratio inclusion' do
          block.aspect_ratio = 'invalid'
          block.valid?
          expect(block.errors[:aspect_ratio]).not_to be_empty
        end

        it 'accepts all valid aspect ratios' do
          VideoBlock::ASPECT_RATIOS.each do |r|
            block.aspect_ratio = r
            block.valid?
            expect(block.errors[:aspect_ratio]).to be_empty
          end
        end
      end

      describe '#provider' do
        it 'identifies youtube.com watch URLs' do
          block.video_url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
          expect(block.provider).to eq(:youtube)
        end

        it 'identifies youtu.be short URLs' do
          block.video_url = 'https://youtu.be/dQw4w9WgXcQ'
          expect(block.provider).to eq(:youtube)
        end

        it 'identifies vimeo URLs' do
          block.video_url = 'https://vimeo.com/123456789'
          expect(block.provider).to eq(:vimeo)
        end

        it 'returns :raw for unknown URLs' do
          block.video_url = 'https://example.com/video.mp4'
          expect(block.provider).to eq(:raw)
        end
      end

      describe '#embed_url' do
        it 'returns YouTube embed URL for youtube.com' do
          block.video_url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
          expect(block.embed_url).to eq('https://www.youtube.com/embed/dQw4w9WgXcQ')
        end

        it 'returns YouTube embed URL for youtu.be' do
          block.video_url = 'https://youtu.be/dQw4w9WgXcQ'
          expect(block.embed_url).to eq('https://www.youtube.com/embed/dQw4w9WgXcQ')
        end

        it 'returns Vimeo player URL' do
          block.video_url = 'https://vimeo.com/123456789'
          expect(block.embed_url).to eq('https://player.vimeo.com/video/123456789')
        end

        it 'returns video_url unchanged for raw provider' do
          block.video_url = 'https://example.com/embed/video'
          expect(block.embed_url).to eq('https://example.com/embed/video')
        end
      end
    end
  end
end
