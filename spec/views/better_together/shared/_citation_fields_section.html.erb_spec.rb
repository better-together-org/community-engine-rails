# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_citation_fields_section', type: :view do
  it 'renders linked citation import controls for contribution citations' do
    page = create(:better_together_page)
    contributor = create(:person, name: 'Import Reviewer')
    contribution = BetterTogether::Authorship.create!(
      authorable: page,
      author: contributor,
      role: 'reviewer',
      contribution_type: 'documentation'
    )
    create(:citation,
           citeable: contribution,
           reference_key: 'review_notes',
           title: 'Review Notes',
           locator: 'p. 11')

    form_builder = ActionView::Helpers::FormBuilder.new(:page, page, view, {})

    render partial: 'better_together/shared/citation_fields_section',
           locals: {
             form: form_builder,
             record: page
           }

    expect(rendered).to include('Import Linked Citation Into This Record')
    expect(rendered).to include('Import Reviewer: Reviewer')
    expect(rendered).to include('Import Citation')
    expect(rendered).to include('review_notes: Review Notes')
  end
end
