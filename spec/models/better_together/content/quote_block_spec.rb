# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe QuoteBlock do
      subject(:block) { described_class.new(quote_text: 'Together we are stronger.') }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is not content_addable pending deferred rollout review' do
        expect(described_class.content_addable?).to be false
      end

      describe 'validations' do
        it 'requires quote_text' do
          block.quote_text = ''
          block.valid?
          expect(block.errors[:quote_text]).not_to be_empty
        end

        it 'is valid with just a quote_text' do
          expect(block).to be_valid
        end
      end

      describe 'defaults' do
        it 'defaults attribution fields to empty string' do
          expect(described_class.new.attribution_name).to eq('')
          expect(described_class.new.attribution_title).to eq('')
          expect(described_class.new.attribution_organization).to eq('')
        end
      end

      describe '#extra_permitted_attributes' do
        it 'includes all quote attributes' do
          attrs = described_class.extra_permitted_attributes
          expect(attrs).to include(:quote_text, :attribution_name, :attribution_title, :attribution_organization)
        end
      end
    end
  end
end
