# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_claims_and_evidence', type: :view do
  it 'renders claims and their supporting evidence links' do
    post = create(:better_together_post)
    citation = create(:better_together_citation, citeable: post, title: 'Evidence Brief', reference_key: 'evidence_brief')
    claim = create(:better_together_claim, claimable: post, claim_key: 'safety_claim', statement: 'Safety guidance should remain evidence-backed.')
    create(:better_together_evidence_link, claim:, citation:, relation_type: 'supports', locator: 'p. 4')

    render partial: 'better_together/shared/claims_and_evidence', locals: { record: post }

    expect(rendered).to include('Claims and Supporting Evidence')
    expect(rendered).to include('Safety guidance should remain evidence-backed.')
    expect(rendered).to include('Evidence Brief')
    expect(rendered).to include('claim-safety_claim')
  end
end
