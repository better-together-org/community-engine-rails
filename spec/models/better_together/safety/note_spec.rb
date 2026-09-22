# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Safety::Note do
  subject(:note) do
    described_class.new(
      safety_case: safety_case,
      author: author,
      body: 'Initial triage complete. Assigned to restorative track.',
      visibility: 'internal_only'
    )
  end

  let(:safety_case) { create(:safety_case) }
  let(:author) { create(:better_together_person) }

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(note).to be_valid
    end

    it 'requires body' do
      note.body = nil
      expect(note).not_to be_valid
    end

    it 'requires visibility' do
      note.visibility = nil
      expect(note).not_to be_valid
    end
  end

  describe 'enums' do
    it 'recognizes visibility values' do
      expect(described_class.visibilities.keys).to include('internal_only', 'participant_visible')
    end
  end

  describe '.chronological scope' do
    it 'orders by created_at ascending' do
      older = create(:better_together_safety_note)
      newer = create(:better_together_safety_note)
      ordered = described_class.chronological.to_a
      expect(ordered.index(older)).to be < ordered.index(newer)
    end
  end
end
