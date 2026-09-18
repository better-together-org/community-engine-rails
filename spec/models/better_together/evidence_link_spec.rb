# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EvidenceLink do
  subject(:evidence_link) { build(:better_together_evidence_link) }

  describe 'RELATION_TYPES constant' do
    it 'includes supports, contests, contextualizes, documents' do
      expect(described_class::RELATION_TYPES).to contain_exactly(
        'supports', 'contests', 'contextualizes', 'documents'
      )
    end
  end

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(evidence_link).to be_valid
    end

    it 'requires relation_type to be in RELATION_TYPES' do
      evidence_link.relation_type = 'irrelevant'
      expect(evidence_link).not_to be_valid
    end

    it 'requires review_status to be a known value' do
      evidence_link.review_status = 'unknown_status'
      expect(evidence_link).not_to be_valid
    end

    it 'enforces uniqueness of citation per claim and relation_type' do
      evidence_link.save!
      duplicate = build(:better_together_evidence_link,
                        claim: evidence_link.claim,
                        citation: evidence_link.citation,
                        relation_type: evidence_link.relation_type)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:citation_id]).to be_present
    end
  end
end
