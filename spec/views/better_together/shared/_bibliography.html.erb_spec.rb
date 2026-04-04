# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_bibliography' do
  it 'renders import audit metadata for linked citation copies' do
    post = create(:better_together_post)
    create(:citation,
           citeable: post,
           reference_key: 'local_copy',
           title: 'Local Citation Copy',
           metadata: {
             'imported_from_reference_key' => 'review_notes',
             'imported_from_record_label' => 'Consensus Reviewer: Reviewer',
             'imported_from_citation_id' => 'source-citation-id'
           })

    render partial: 'better_together/shared/bibliography', locals: { record: post }

    expect(rendered).to include('Imported from linked citation:')
    expect(rendered).to include('Consensus Reviewer: Reviewer | review_notes')
  end
end
