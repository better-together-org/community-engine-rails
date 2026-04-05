# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::GithubContributionImportsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:manager_user) do
    BetterTogether::User.find_by(email: 'manager@example.test') ||
      create(
        :user,
        :platform_manager,
        email: 'manager@example.test',
        password: 'SecureTest123!@#'
      )
  end
  let(:page) { create(:better_together_page) }
  let(:joatu_request) { create(:better_together_joatu_request) }
  let(:joatu_agreement) { create(:joatu_agreement) }

  before { sign_in manager_user }

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

  it 'imports github activity into a joatu request contribution record' do
    post better_together.github_contribution_imports_path(
      contributable_key: 'joatu_request',
      id: joatu_request.slug,
      locale:,
      format: :json
    ), params: {
      source: {
        reference_key: 'commit_aab525784',
        source_kind: 'commit',
        title: 'Extend governed listing evidence summaries',
        source_url: 'https://github.com/better-together-org/community-engine-rails/commit/aab525784',
        locator: 'aab525784',
        metadata: {
          repository_name: 'better-together-org/community-engine-rails',
          commit_sha: 'aab525784',
          github_handle: 'user'
        }
      }
    }, as: :json

    expect(response).to have_http_status(:ok)
    contribution = joatu_request.reload.contributions.find(JSON.parse(response.body).dig('contribution', 'id'))
    expect(contribution.author).to eq(manager_user.person)
    expect(contribution.details['github_sources'].first['commit_sha']).to eq('aab525784')
  end

  it 'imports github activity into a joatu agreement contribution record' do
    post better_together.github_contribution_imports_path(
      contributable_key: 'joatu_agreement',
      id: joatu_agreement.slug,
      locale:,
      format: :json
    ), params: {
      source: {
        reference_key: 'issue_1494_followup',
        source_kind: 'issue',
        title: 'Track exchange governance follow-up',
        source_url: 'https://github.com/better-together-org/community-engine-rails/issues/1494',
        locator: '#1494',
        metadata: {
          repository_name: 'better-together-org/community-engine-rails',
          issue_number: 1494,
          github_handle: 'user'
        }
      }
    }, as: :json

    expect(response).to have_http_status(:ok)
    contribution = joatu_agreement.reload.contributions.find(JSON.parse(response.body).dig('contribution', 'id'))
    expect(contribution.author).to eq(manager_user.person)
    expect(contribution.role).to eq('idea_source')
    expect(contribution.details['github_sources'].first['issue_number']).to eq(1494)
  end
end
