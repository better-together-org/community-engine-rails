# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe CommunitiesBlock do
      subject(:block) { described_class.new(display_style: 'grid', item_limit: 6) }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'includes ResourceBlockAttributes' do
        expect(described_class.ancestors).to include(BetterTogether::Content::ResourceBlockAttributes)
      end

      it 'is not content_addable pending deferred rollout review' do
        expect(described_class.content_addable?).to be false
      end

      describe 'validations' do
        it 'accepts valid display_style values' do
          %w[grid list].each do |style|
            block.display_style = style
            block.valid?
            expect(block.errors[:display_style]).to be_empty
          end
        end
      end
    end
  end
end
