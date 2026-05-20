# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe AccordionBlock do
      subject(:block) { described_class.new }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is content_addable' do
        expect(described_class.content_addable?).to be true
      end

      describe 'defaults' do
        it 'defaults accordion_items_json to empty array string' do
          expect(described_class.new.accordion_items_json).to eq('[]')
        end

        it 'defaults open_first to true' do
          expect(described_class.new.open_first).to eq('true')
        end
      end

      describe '#open_first?' do
        it 'returns true when open_first is "true"' do
          block.open_first = 'true'
          expect(block.open_first?).to be true
        end

        it 'returns false when open_first is "false"' do
          block.open_first = 'false'
          expect(block.open_first?).to be false
        end
      end

      describe '#parsed_accordion_items' do
        it 'returns [] for empty array JSON' do
          block.accordion_items_json = '[]'
          expect(block.parsed_accordion_items).to eq([])
        end

        it 'parses valid JSON with symbolized keys' do
          block.accordion_items_json = '[{"question":"What?","answer":"This."}]'
          result = block.parsed_accordion_items
          expect(result.first).to include(question: 'What?', answer: 'This.')
        end

        it 'returns [] on invalid JSON' do
          block.accordion_items_json = 'not json'
          expect(block.parsed_accordion_items).to eq([])
        end
      end

      describe '#extra_permitted_attributes' do
        it 'includes all accordion attributes' do
          attrs = described_class.extra_permitted_attributes
          expect(attrs).to include(:heading, :accordion_items_json, :open_first)
        end
      end
    end
  end
end
