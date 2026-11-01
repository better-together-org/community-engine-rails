# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agent credentials on the REST API', :no_auth do
  let(:platform) { BetterTogether::Platform.find_by!(host: true) }
  let(:operator_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:operator) { operator_user.person }
  let(:robot) { create(:robot, platform: platform) }
  let(:community_a) { create(:better_together_community) }
  let(:community_b) { create(:better_together_community) }
  let!(:endpoint_a) { create(:better_together_webhook_endpoint, person: operator, community: community_a) }
  let!(:endpoint_b) { create(:better_together_webhook_endpoint, person: operator, community: community_b) }
  let!(:endpoint_other) { create(:better_together_webhook_endpoint, person: create(:better_together_person)) }
  let(:grant_scopes) { %w[read admin] }
  let(:app_scopes) { 'read admin' }
  let(:app_community) { nil }

  let!(:grant) do
    create(:better_together_agent_grant, robot: robot, operator: operator, platform: platform,
                                         community: app_community, scopes: grant_scopes)
  end
  let(:application) do
    create(:better_together_oauth_application, owner: operator, robot: robot, platform: platform,
                                               community: app_community, scopes: app_scopes,
                                               redirect_uri: 'urn:ietf:wg:oauth:2.0:oob')
  end

  def agent_headers(scope: 'read admin')
    post '/api/oauth/token', params: { grant_type: 'client_credentials', client_id: application.uid,
                                       client_secret: application.plaintext_secret, scope: scope }
    token = JSON.parse(response.body).fetch('access_token')
    { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/vnd.api+json' }
  end

  def listed_ids
    JSON.parse(response.body)['data'].map { |row| row['id'] }
  end

  describe 'platform-wide agent' do
    it 'acts with the operator permissions' do
      get '/api/v1/webhook_endpoints', headers: agent_headers

      expect(response).to have_http_status(:ok)
      expect(listed_ids).to include(endpoint_a.id, endpoint_b.id)
    end
  end

  describe 'privilege escalation' do
    let(:grant_scopes) { %w[read] }

    it 'cannot use a token scope the grant does not carry' do
      headers = agent_headers(scope: 'read admin')

      post '/api/v1/webhook_endpoints', headers: headers.merge('Content-Type' => 'application/vnd.api+json'),
                                        params: { data: { type: 'webhook_endpoints',
                                                          attributes: { name: 'x', url: 'https://example.com/hook' } } }.to_json

      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses a grant that exceeds what its operator may delegate' do
      plain = create(:better_together_user, :confirmed).person
      bad = build(:better_together_agent_grant, robot: robot, operator: plain, platform: platform,
                                                scopes: %w[admin])

      expect(bad).not_to be_valid
      expect(bad.errors[:scopes].join).to include('admin')
    end
  end

  describe 'operator demotion' do
    it 'narrows the agent on the next request' do
      headers = agent_headers
      get '/api/v1/webhook_endpoints', headers: headers
      expect(listed_ids).to include(endpoint_other.id)

      operator.person_platform_memberships.destroy_all
      get '/api/v1/webhook_endpoints', headers: headers

      expect(listed_ids).not_to include(endpoint_other.id)
    end
  end

  describe 'grant lifecycle' do
    it 'fails closed once the grant is revoked' do
      headers = agent_headers
      grant.revoke!

      get '/api/v1/webhook_endpoints', headers: headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'fails closed once the grant has expired' do
      headers = agent_headers
      grant.update_columns(expires_at: 1.minute.ago)

      get '/api/v1/webhook_endpoints', headers: headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'token lifecycle' do
    # /communities declares no scopes, so only the token check can stop these.
    it 'rejects a revoked access token' do
      headers = agent_headers
      application.access_tokens.update_all(revoked_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

      get '/api/v1/communities', headers: headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects an expired access token' do
      headers = agent_headers
      application.access_tokens.update_all(created_at: 1.day.ago) # rubocop:disable Rails/SkipsModelValidations

      get '/api/v1/communities', headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'platform binding' do
    let(:other_platform) { create(:better_together_platform) }
    let(:robot) { create(:robot, platform: other_platform) }
    let!(:grant) do
      create(:better_together_agent_grant, robot: robot, operator: operator, platform: other_platform,
                                           scopes: grant_scopes)
    end
    let(:application) do
      create(:better_together_oauth_application, owner: operator, robot: robot, platform: other_platform,
                                                 scopes: app_scopes, redirect_uri: 'urn:ietf:wg:oauth:2.0:oob')
    end

    it 'rejects a credential used on a host that resolves to a different platform' do
      get '/api/v1/webhook_endpoints', headers: agent_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'fail closed on actor resolution errors' do
    it 'denies instead of acting as the application owner' do
      headers = agent_headers
      allow(BetterTogether::Api::TokenActor).to receive(:from_token).and_raise(ActiveRecord::StatementInvalid)

      get '/api/v1/communities', headers: headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'cross-community isolation' do
    let(:app_community) { community_a }

    it 'lists only records of the credential community' do
      get '/api/v1/webhook_endpoints', headers: agent_headers

      expect(response).to have_http_status(:ok)
      expect(listed_ids).to contain_exactly(endpoint_a.id)
    end

    it 'returns 404 for a record in another community' do
      get "/api/v1/webhook_endpoints/#{endpoint_b.id}", headers: agent_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'does not widen what the same operator sees through a normal session' do
      get "/api/v1/webhook_endpoints/#{endpoint_a.id}", headers: agent_headers

      expect(response).to have_http_status(:ok)
    end
  end
end
