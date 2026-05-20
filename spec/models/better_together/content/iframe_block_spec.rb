# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe IframeBlock do
      subject(:block) { described_class.new(iframe_url: 'https://forms.btsdev.ca/s/example') }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is content_addable' do
        expect(described_class.content_addable?).to be true
      end

      it 'defaults aspect_ratio to 16x9' do
        expect(described_class.new.aspect_ratio).to eq('16x9')
      end

      it 'requires iframe_url' do
        block.iframe_url = ''
        block.valid?

        expect(block.errors[:iframe_url]).not_to be_empty
      end

      it 'rejects non-https iframe URLs' do
        block.iframe_url = 'http://example.com/embed'
        block.valid?

        expect(block.errors[:iframe_url]).not_to be_empty
      end

      it 'returns the configured iframe URL as the embed URL' do
        expect(block.embed_url).to eq('https://forms.btsdev.ca/s/example')
      end
    end
  end
end
