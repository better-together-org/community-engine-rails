# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_bibliography', type: :view do
  it 'renders structured bibliography entries with apa and mla exports' do
    post = create(:better_together_post)
    create(:better_together_citation,
           citeable: post,
           title: 'Community Action Evidence',
           reference_key: 'community_action_evidence')

    render partial: 'better_together/shared/bibliography', locals: { record: post }

    expect(rendered).to include('Evidence and Citations')
    expect(rendered).to include('Community Action Evidence')
    expect(rendered).to include('APA:')
    expect(rendered).to include('MLA:')
    expect(rendered).to include('citation-community_action_evidence')
  end
end
