# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_github_contribution_import_panel' do
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

  it 'renders github contribution import controls for persisted records and signed-in users' do
    page = create(:better_together_page)
    user = create(:user)

    create(:person_platform_integration,
           :github,
           user:,
           person: user.person,
           platform: github_platform,
           handle: 'contribution-editor')

    allow(view).to receive(:current_user).and_return(user)

    render partial: 'better_together/shared/github_contribution_import_panel',
           locals: { record: page }

    expect(rendered).to include('Import GitHub Contribution')
    expect(rendered).to include('Load GitHub Contribution Sources')
    expect(rendered).to include('data-better_together--github-contribution-import-import-url-value=')
  end
end
