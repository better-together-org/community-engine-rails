# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::GithubContributionImportsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:manager_user) do
    BetterTogether::User.find_by(email: 'manager@example.test') || create(:user,
                                                                           :platform_manager,
                                                                           email: 'manager@example.test',
                                                                           password: 'SecureTest123!@#')
  end
  let(:page) { create(:better_together_page) }

  it 'imports github activity into a governed contribution record for the current person' do
    post better_together.github_contribution_imports_path(
      contributable_key: 'page',
      id: page.slug,
      locale:,
      format: :json
    ), params: {
      source: {
        reference_key: 'pull_request_1494',
        source_kind: 'pull_request',
        title: 'Governed publishing and evidence chain',
        source_url: 'https://github.com/better-together-org/community-engine-rails/pull/1494',
        locator: 'PR #1494',
        metadata: {
          repository_name: 'better-together-org/community-engine-rails',
          pull_request_number: 1494,
          github_handle: 'user'
        }
      }
    }, as: :json

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['contribution']['role']).to eq('author')
    expect(json['contribution']['contribution_type']).to eq('code')

    contribution = page.reload.contributions.find(json['contribution']['id'])
    expect(contribution.author).to eq(manager_user.person)
    expect(contribution.details['github_sources'].first['pull_request_number']).to eq(1494)
  end
end
