# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe QuoteBlock do
      subject(:block) { described_class.new(quote_text: 'Together we are stronger.') }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is content_addable for an alpha-entitled actor' do
        # new_content_blocks defaults to alpha rollout — content_addable? delegates
        # to FeatureGate, which requires alpha access for an actor to see true.
        allow(BetterTogether::FeatureGate).to receive(:enabled?).with('new_content_blocks', anything).and_return(true)

        expect(described_class.content_addable?).to be true
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
        it 'defaults attribution fields to nil (Mobility translated attributes have no built-in default)' do
          expect(described_class.new.attribution_name).to be_nil
          expect(described_class.new.attribution_title).to be_nil
          expect(described_class.new.attribution_organization).to be_nil
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
