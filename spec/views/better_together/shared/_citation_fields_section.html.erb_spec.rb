# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_citation_fields_section' do
  let!(:github_platform) do
    BetterTogether::Platform.external.find_or_create_by!(identifier: 'github') do |platform|
      platform.name = 'GitHub'
      platform.url = 'https://github.com'
      platform.description = 'GitHub OAuth Provider'
      platform.time_zone = 'UTC'
      platform.privacy = :public
      platform.host = false
    end
  end

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
    expect(rendered).to include('data-citation-id=')
    expect(rendered).to include('data-record-label=')
  end

  it 'renders github citation import controls for signed-in users with linked github identities' do
    page = create(:better_together_page)
    user = create(:user)
    create(:person_platform_integration,
           :github,
           user:,
           person: user.person,
           platform: github_platform,
           handle: 'evidence-editor',
           auth: {
             'citation_import_preview' => [
               {
                 'reference_key' => 'repository_community_engine_rails',
                 'source_kind' => 'repository',
                 'title' => 'better-together-org/community-engine-rails'
               }
             ]
           })

    allow(view).to receive(:current_user).and_return(user)

    form_builder = ActionView::Helpers::FormBuilder.new(:page, page, view, {})

    render partial: 'better_together/shared/citation_fields_section',
           locals: {
             form: form_builder,
             record: page
           }

    expect(rendered).to include('Import GitHub Citation')
    expect(rendered).to include('Load GitHub Sources')
    expect(rendered).to include('data-better_together--citation-import-github-url-value=')
  end
end
