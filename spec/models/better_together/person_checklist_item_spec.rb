# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonChecklistItem do
  subject(:pci) do
    described_class.new(person: person, checklist: checklist, checklist_item: item)
  end

  let(:person) { create(:better_together_person) }
  let(:checklist) { create(:better_together_checklist) }
  let(:item) { create(:better_together_checklist_item, checklist: checklist) }

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(pci).to be_valid
    end

    it 'requires person' do
      pci.person = nil
      expect(pci).not_to be_valid
    end

    it 'requires checklist' do
      pci.checklist = nil
      expect(pci).not_to be_valid
    end

    it 'requires checklist_item' do
      pci.checklist_item = nil
      expect(pci).not_to be_valid
    end
  end

  describe '#mark_done!' do
    it 'sets completed_at' do
      pci.save!
      pci.mark_done!
      expect(pci.reload.completed_at).to be_present
    end
  end

  describe '#mark_undone!' do
    it 'clears completed_at' do
      pci.completed_at = Time.current
      pci.save!
      pci.mark_undone!
      expect(pci.reload.completed_at).to be_nil
    end
  end

  describe '#done?' do
    it 'returns false when not completed' do
      pci.save!
      expect(pci.done?).to be false
    end

    it 'returns true when completed_at is set' do
      pci.save!
      pci.mark_done!
      expect(pci.done?).to be true
    end
  end

  describe '.completed scope' do
    it 'returns records with completed_at set' do
      pci.save!
      pci.mark_done!
      expect(described_class.completed).to include(pci)
    end

    it 'excludes pending records' do
      pci.save!
      expect(described_class.completed).not_to include(pci)
    end
  end

  describe '.pending scope' do
    it 'returns records without completed_at' do
      pci.save!
      expect(described_class.pending).to include(pci)
    end
  end
end
