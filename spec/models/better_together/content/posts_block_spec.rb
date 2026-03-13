# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe PostsBlock do
      subject(:block) { described_class.new(display_style: 'grid', item_limit: 6, posts_scope: 'published') }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is content_addable' do
        expect(described_class.content_addable?).to be true
      end

      describe '#posts_scope' do
        it 'defaults to published' do
          expect(described_class.new.posts_scope).to eq('published')
        end

        it 'validates inclusion in POSTS_SCOPES' do
          block.posts_scope = 'invalid'
          block.valid?
          expect(block.errors[:posts_scope]).not_to be_empty
        end

        it 'accepts all valid scopes' do
          BetterTogether::Content::PostsBlock::POSTS_SCOPES.each do |scope|
            block.posts_scope = scope
            block.valid?
            expect(block.errors[:posts_scope]).to be_empty
          end
        end
      end
    end
  end
end
