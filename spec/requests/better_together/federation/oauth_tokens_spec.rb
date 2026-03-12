# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Federation::OauthTokens', :no_auth do
  let(:locale) { I18n.default_locale }
  let(:source_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:source_hostname) { "source-#{SecureRandom.hex(4)}.example.test" }
  let(:target_platform) { create(:better_together_platform, :community_engine_peer) }
  let(:connection) do
    create(
      :better_together_platform_connection,
      :active,
      source_platform:,
      target_platform:,
      federation_auth_policy: 'api_read',
      content_sharing_policy: 'mirror_network_feed',
      share_posts: true,
      allow_identity_scope: true,
      allow_content_read_scope: true
    )
  end

  before do
    source_platform.update!(
      host_url: 'https://primary.example.test',
      privacy: 'public',
      requires_invitation: false
    )

    create(
      :better_together_platform_domain,
      platform: source_platform,
      hostname: source_hostname,
      primary: false,
      active: true
    )

    host! source_hostname
  end

  it 'issues a scoped bearer token for a valid client credentials request' do
    post better_together.federation_oauth_token_path(locale:),
         params: {
           grant_type: 'client_credentials',
           client_id: connection.oauth_client_id,
           client_secret: connection.oauth_client_secret,
           scope: 'content.feed.read'
         }

    expect(response).to have_http_status(:ok)

    payload = JSON.parse(response.body)
    expect(payload['access_token']).to be_present
    expect(payload['token_type']).to eq('Bearer')
    expect(payload['scope']).to eq('content.feed.read')
  end

  it 'rejects an invalid client secret' do
    post better_together.federation_oauth_token_path(locale:),
         params: {
           grant_type: 'client_credentials',
           client_id: connection.oauth_client_id,
           client_secret: 'wrong-secret',
           scope: 'content.feed.read'
         }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to include('error' => 'invalid_client')
  end

  it 'rejects a scope that the connection is not allowed to use' do
    post better_together.federation_oauth_token_path(locale:),
         params: {
           grant_type: 'client_credentials',
           client_id: connection.oauth_client_id,
           client_secret: connection.oauth_client_secret,
           scope: 'linked_content.read'
         }

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)).to include('error' => 'invalid_scope')
  end
end
