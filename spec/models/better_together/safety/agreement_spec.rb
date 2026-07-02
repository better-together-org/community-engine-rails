# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Safety::Agreement do
  subject(:agreement) do
    described_class.new(
      safety_case: safety_case,
      created_by: author,
      status: 'proposed',
      summary: 'Both parties agree to no further direct contact.',
      commitments: 'Refrain from posting about the other party.'
    )
  end

  let(:safety_case) { create(:safety_case) }
  let(:author) { create(:better_together_person) }

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(agreement).to be_valid
    end

    it 'requires summary' do
      agreement.summary = nil
      expect(agreement).not_to be_valid
    end

    it 'requires commitments' do
      agreement.commitments = nil
      expect(agreement).not_to be_valid
    end

    it 'requires status' do
      agreement.status = nil
      expect(agreement).not_to be_valid
    end
  end

  describe 'enums' do
    it 'recognizes all status values' do
      expect(described_class.statuses.keys).to include(
        'proposed', 'active', 'completed', 'breached', 'withdrawn'
      )
    end
  end

  describe '.recent_first scope' do
    it 'orders by created_at descending' do
      older = create(:better_together_safety_agreement)
      newer = create(:better_together_safety_agreement)
      ordered = described_class.recent_first.to_a
      expect(ordered.index(newer)).to be < ordered.index(older)
    end
  end
end
