# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ChecklistItem do
  subject(:item) do
    build(:better_together_checklist_item, checklist: checklist, label: 'Step one')
  end

  let(:checklist) { create(:better_together_checklist) }

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(item).to be_valid
    end

    it 'requires label' do
      item.label = nil
      expect(item).not_to be_valid
    end
  end

  describe 'MAX_NESTING_DEPTH constant' do
    it 'is 2' do
      expect(described_class::MAX_NESTING_DEPTH).to eq(2)
    end
  end

  describe '#depth' do
    it 'returns 0 for a top-level item (no parent)' do
      item.save!
      expect(item.depth).to eq(0)
    end

    it 'returns 1 for a direct child' do
      parent = create(:better_together_checklist_item, checklist: checklist)
      child = create(:better_together_checklist_item, checklist: checklist, parent: parent)
      expect(child.depth).to eq(1)
    end
  end

  describe 'parent nesting validation' do
    it 'rejects items nested beyond MAX_NESTING_DEPTH' do
      grandparent = create(:better_together_checklist_item, checklist: checklist)
      parent = create(:better_together_checklist_item, checklist: checklist, parent: grandparent)
      child = create(:better_together_checklist_item, checklist: checklist, parent: parent)
      great_grandchild = build(:better_together_checklist_item, checklist: checklist, parent: child)
      expect(great_grandchild).not_to be_valid
      expect(great_grandchild.errors[:parent_id]).to be_present
    end
  end

  describe '#to_s' do
    it 'returns the label' do
      item.label = 'Complete intake form'
      expect(item.to_s).to eq('Complete intake form')
    end
  end

  describe 'associations' do
    it 'belongs to a checklist' do
      item.save!
      expect(item.checklist).to eq(checklist)
    end

    it 'can have children' do
      item.save!
      expect(item).to respond_to(:children)
    end
  end
end
