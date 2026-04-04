# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_record_evidence_summary', type: :view do
  it 'renders claim, citation, and imported citation counts' do
    page = create(:better_together_page)
    create(:claim, claimable: page, statement: 'Shared reality depends on traceable evidence.')
    create(:citation,
           citeable: page,
           reference_key: 'source_one',
           title: 'Source One',
           metadata: {
             'imported_from_reference_key' => 'review_notes',
             'imported_from_record_label' => 'Consensus Reviewer: Reviewer',
             'imported_from_citation_id' => 'source-citation-id'
           })

    render partial: 'better_together/shared/record_evidence_summary', locals: { record: page }

    expect(rendered).to include('Evidence:')
    expect(rendered).to include('1 claim')
    expect(rendered).to include('1 citation')
    expect(rendered).to include('1 imported')
    expect(rendered).to include('Governance Bundle')
    expect(rendered).to include('CSL Export')
  end
end
