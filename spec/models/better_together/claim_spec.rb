# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Claim do
  describe 'normalization and relationships' do
    it 'normalizes the claim key from the statement when missing' do
      claim = build(:better_together_claim, claim_key: nil, statement: 'Community members deserve evidence-backed claims.')

      claim.validate

      expect(claim.claim_key).to eq('community_members_deserve_evidence-backed_claims')
    end

    it 'can connect to citations through evidence links' do
      post = create(:better_together_post)
      citation = create(:better_together_citation, citeable: post, reference_key: 'shared_reality_note')
      claim = create(:better_together_claim, claimable: post)
      create(:better_together_evidence_link, claim:, citation:)

      expect(claim.citations).to contain_exactly(citation)
    end
  end
end
