# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe NavigationAreaBlock do
      subject(:block) { described_class.new(display_style: 'grid', item_limit: 6) }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is content_addable' do
        expect(described_class.content_addable?).to be true
      end

      describe 'validations' do
        it 'requires navigation_area_id' do
          block.navigation_area_id = ''
          block.valid?
          expect(block.errors[:navigation_area_id]).not_to be_empty
        end

        it 'passes when navigation_area_id is present' do
          block.navigation_area_id = SecureRandom.uuid
          block.valid?
          expect(block.errors[:navigation_area_id]).to be_empty
        end
      end

      describe '#navigation_area' do
        it 'returns nil when navigation_area_id is blank' do
          expect(block.navigation_area).to be_nil
        end

        it 'returns nil when navigation_area_id does not match a record' do
          block.navigation_area_id = SecureRandom.uuid
          expect(block.navigation_area).to be_nil
        end
      end
    end
  end
end
