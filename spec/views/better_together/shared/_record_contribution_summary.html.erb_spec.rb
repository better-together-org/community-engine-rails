# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_record_contribution_summary' do
  it 'renders github-backed contribution counts and handles for authorable records' do
    page = create(:better_together_page)
    contributor = create(:better_together_person, name: 'Summary Maintainer')
    page.add_governed_contributor(contributor, role: 'editor')
    page.contributions.first.update!(details: {
                                       'github_handle' => 'summary-maintainer',
                                       'github_sources' => [
                                         { 'reference_key' => 'pull_request_1494' },
                                         { 'reference_key' => 'commit_abc123' }
                                       ]
                                     })

    render partial: 'better_together/shared/record_contribution_summary', locals: { record: page }

    expect(rendered).to include('Contributors:')
    expect(rendered).to include('1 governed')
    expect(rendered).to include('1 GitHub-linked')
    expect(rendered).to include('2 GitHub sources')
    expect(rendered).to include('GitHub: @summary-maintainer')
  end
end
