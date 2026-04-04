# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::GithubCitationImportsController', :as_user do
  let(:locale) { I18n.default_locale }
  let(:user) do
    BetterTogether::User.find_by(email: 'user@example.test') || create(:user,
                                                                        email: 'user@example.test',
                                                                        password: 'SecureTest123!@#')
  end
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

  before do
    create(:person_platform_integration,
           :github,
           user:,
           person: user.person,
           platform: github_platform,
           handle: 'linked-reviewer',
           auth: {
             'citation_import_preview' => [
               {
                 'reference_key' => 'repository_community_engine_rails',
                 'source_kind' => 'repository',
                 'title' => 'better-together-org/community-engine-rails',
                 'source_author' => 'better-together-org',
                 'publisher' => 'GitHub',
                 'source_url' => 'https://github.com/better-together-org/community-engine-rails',
                 'metadata' => {
                   'repository_name' => 'better-together-org/community-engine-rails',
                   'repository_path' => 'better-together-org/community-engine-rails',
                   'github_handle' => 'linked-reviewer'
                 }
               },
               {
                 'reference_key' => 'pull_request_1494',
                 'source_kind' => 'pull_request',
                 'title' => 'Governed publishing and evidence chain',
                 'source_author' => 'linked-reviewer',
                 'publisher' => 'GitHub',
                 'source_url' => 'https://github.com/better-together-org/community-engine-rails/pull/1494',
                 'locator' => 'PR #1494',
                 'metadata' => {
                   'repository_name' => 'better-together-org/community-engine-rails',
                   'pull_request_number' => 1494,
                   'github_handle' => 'linked-reviewer'
                 }
               }
             ]
           })
  end

  it 'returns importable github citation candidates for the signed-in person' do
    get better_together.github_citation_imports_path(locale:, format: :json)

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['groups'].size).to eq(1)
    expect(json['groups'].first['label']).to eq('GitHub: @linked-reviewer')
    expect(json['groups'].first['citations'].map { |citation| citation['source_kind'] }).to include('repository', 'pull_request')
    expect(json['groups'].first['citations'].first['metadata']['repository_name']).to eq('better-together-org/community-engine-rails')
  end
end
