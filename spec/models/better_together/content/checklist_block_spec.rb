# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe ChecklistBlock do
      subject(:block) { described_class.new(display_style: 'grid', item_limit: 6) }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is not content_addable pending deferred rollout review' do
        expect(described_class.content_addable?).to be false
      end

      describe 'validations' do
        it 'requires checklist_id' do
          block.checklist_id = ''
          block.valid?
          expect(block.errors[:checklist_id]).not_to be_empty
        end

        it 'passes when checklist_id is present' do
          block.checklist_id = SecureRandom.uuid
          block.valid?
          expect(block.errors[:checklist_id]).to be_empty
        end
      end

      describe '#checklist' do
        it 'returns nil when checklist_id is blank' do
          expect(block.checklist).to be_nil
        end

        it 'returns nil when checklist_id does not match a record' do
          block.checklist_id = SecureRandom.uuid
          expect(block.checklist).to be_nil
        end
      end
    end
  end
end
