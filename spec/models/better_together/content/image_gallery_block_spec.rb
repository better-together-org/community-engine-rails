# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe ImageGalleryBlock do
      subject(:block) { described_class.new }

      def build_image(token)
        create(:better_together_content_image, identifier: "gallery-model-#{token}-#{SecureRandom.hex(3)}").tap do |image|
          image.media.attach(io: File.open(BetterTogether::Engine.root.join('app/assets/images/better_together/unsplash-community-1.jpeg')),
                             filename: 'a.jpg', content_type: 'image/jpeg')
        end
      end

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is content_addable' do
        expect(described_class.content_addable?).to be true
      end

      it 'defaults to a grid with a lightbox and no images', :aggregate_failures do
        expect(block.layout).to eq('grid')
        expect(block.lightbox?).to be true
        expect(block.parsed_image_ids).to eq([])
        expect(block.images).to eq([])
      end

      it 'permits every content_data key' do
        expect(described_class.extra_permitted_attributes).to include(:image_ids, :layout, :lightbox, :heading)
      end

      it 'rejects an unknown layout' do
        block.layout = 'carousel'
        block.valid?
        expect(block.errors[:layout]).not_to be_empty
      end

      it 'accepts masonry' do
        block.layout = 'masonry'
        block.valid?
        expect(block.errors[:layout]).to be_empty
      end

      it 'parses JSON and comma separated id lists' do
        block.image_ids = '["a","b"]'
        expect(block.parsed_image_ids).to eq(%w[a b])
        block.image_ids = 'a, b'
        expect(block.parsed_image_ids).to eq(%w[a b])
      end

      it 'returns images in the configured order and skips missing ids' do
        first = build_image('one')
        second = build_image('two')
        block.image_ids = [second.id, SecureRandom.uuid, first.id].to_json
        expect(block.images).to eq([second, first])
      end

      it 'stores a translatable heading' do
        block.heading_fr = 'Photos du terrain'
        expect(block.heading_fr).to eq('Photos du terrain')
      end
    end
  end
end
