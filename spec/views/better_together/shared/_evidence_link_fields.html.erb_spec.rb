# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_evidence_link_fields', type: :view do
  it 'renders grouped citation options from the current record and linked contributions' do
    page = create(:better_together_page)
    create(:citation, citeable: page, reference_key: 'local_record', title: 'Local Record Citation')

    contributor = create(:person, name: 'Consensus Reviewer')
    contribution = BetterTogether::Authorship.create!(
      authorable: page,
      author: contributor,
      role: 'reviewer'
    )
    create(:citation, citeable: contribution, reference_key: 'review_notes', title: 'Review Notes')

    claim = page.claims.build
    evidence_link = claim.evidence_links.build
    form_builder = ActionView::Helpers::FormBuilder.new(:evidence_link, evidence_link, view, {})

    render partial: 'better_together/shared/evidence_link_fields',
           locals: {
             evidence_link_fields: form_builder,
             record: page
           }

    expect(rendered).to include('Current record')
    expect(rendered).to include('Consensus Reviewer: Reviewer')
    expect(rendered).to include('local_record: Local Record Citation')
    expect(rendered).to include('review_notes: Review Notes')
  end
end
