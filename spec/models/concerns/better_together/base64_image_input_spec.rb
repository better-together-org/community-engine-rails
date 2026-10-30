# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Base64ImageInput do
  let(:png) do
    Base64.strict_decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
  end
  let(:data) { Base64.strict_encode64(png) }

  describe BetterTogether::Content::Hero do
    let(:block) do
      described_class.new(privacy: 'private', identifier: 'hero-api-test', creator: create(:better_together_person),
                          background_image_data: data, background_image_filename: 'ship.png', heading: 'EXPLORA III')
    end

    it 'attaches a base64 background image', :aggregate_failures do
      block.save!

      expect(block.reload.background_image_file).to be_attached
      expect(block.background_image_file.content_type).to eq('image/png')
      expect(block.background_image_file.filename.to_s).to eq('ship.png')
    end

    it 'rejects data that is not an allowed image', :aggregate_failures do
      block.background_image_data = Base64.strict_encode64('not an image')

      expect(block).not_to be_valid
      expect(block.errors[:background_image_data]).to include('must be a JPEG, PNG or WebP image')
    end

    it 'does not keep the data after saving' do
      block.save!

      expect(block.background_image_data).to be_nil
    end

    it 'replaces the background of a saved block without recursing' do
      block.save!
      block.update!(background_image_data: data, background_image_filename: 'replacement.png')

      expect(block.reload.background_image_file.filename.to_s).to eq('replacement.png')
    end

    it 'leaves an existing background alone when no data is sent' do
      block.save!
      block.update!(heading: 'EXPLORA III (updated)')

      expect(block.reload.background_image_file).to be_attached
    end
  end

  describe BetterTogether::Content::Image do
    let(:block) do
      described_class.new(privacy: 'private', identifier: 'image-api-test', creator: create(:better_together_person),
                          media_data: data, media_filename: 'ship.png', caption: 'EXPLORA III')
    end

    it 'attaches a base64 image', :aggregate_failures do
      block.save!

      expect(block.reload.media).to be_attached
      expect(block.media.filename.to_s).to eq('ship.png')
    end

    it 'requires a caption for an image created from base64 data', :aggregate_failures do
      block.caption = nil

      expect(block).not_to be_valid
      expect(block.errors[:caption]).to be_present
    end

    it 'keeps the caption requirement after the data has been consumed' do
      block.caption = nil
      block.valid?

      expect(block.media_data_received?).to be(true)
    end

    it 'replaces the image of a saved block without recursing' do
      block.save!
      block.update!(media_data: data, media_filename: 'replacement.png')

      expect(block.reload.media.filename.to_s).to eq('replacement.png')
    end
  end
end
