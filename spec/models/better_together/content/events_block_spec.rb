# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe EventsBlock, type: :model do
      subject(:block) { described_class.new(display_style: 'grid', item_limit: 6, event_scope: 'upcoming') }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is content_addable' do
        expect(described_class.content_addable?).to be true
      end

      describe '#event_scope' do
        it 'defaults to upcoming' do
          expect(described_class.new.event_scope).to eq('upcoming')
        end

        it 'validates inclusion in EVENT_SCOPES' do
          block.event_scope = 'invalid'
          block.valid?
          expect(block.errors[:event_scope]).not_to be_empty
        end

        it 'accepts all valid scopes' do
          BetterTogether::Content::EventsBlock::EVENT_SCOPES.each do |scope|
            block.event_scope = scope
            block.valid?
            expect(block.errors[:event_scope]).to be_empty
          end
        end
      end
    end
  end
end
