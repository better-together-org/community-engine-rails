# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe PeopleBlock do
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

      describe '#parsed_resource_ids' do
        it 'returns [] when resource_ids is blank' do
          expect(block.parsed_resource_ids).to eq([])
        end

        it 'parses a JSON array string' do
          block.resource_ids = '["abc","def"]'
          expect(block.parsed_resource_ids).to eq(%w[abc def])
        end

        it 'falls back to comma-split for plain strings' do
          block.resource_ids = 'abc, def'
          expect(block.parsed_resource_ids).to eq(%w[abc def])
        end
      end

      describe 'validations' do
        it 'validates display_style inclusion' do
          block.display_style = 'invalid'
          block.valid?
          expect(block.errors[:display_style]).not_to be_empty
        end

        it 'validates item_limit is positive' do
          block.item_limit = 0
          block.valid?
          expect(block.errors[:item_limit]).not_to be_empty
        end
      end
    end
  end
end
