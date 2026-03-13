# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Federation::ContentFeed', :no_auth do
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
      content_sharing_policy: 'mirror_network_feed',
      federation_auth_policy: 'api_read',
      share_posts: true,
      allow_identity_scope: true,
      allow_content_read_scope: true
    )
  end
  let(:oauth_access_token) do
    BetterTogether::FederationAccessTokenIssuer.call(
      connection:,
      requested_scopes: 'content.feed.read'
    ).access_token
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

  after do
    source_platform.update_columns(host_url: 'http://www.example.com')
  end

  it 'returns a cursor-paginated content batch for an authorized peer' do
    post = create(:better_together_post, platform: source_platform, privacy: 'public', published_at: 1.day.ago)

    get better_together.federation_content_feed_path(locale:),
        headers: { 'Authorization' => "Bearer #{oauth_access_token}" }

    expect(response).to have_http_status(:ok)

    payload = JSON.parse(response.body)
    expect(payload['seeds'].first['better_together']['payload']['type']).to eq('post')
    expect(payload['seeds'].first['better_together']['payload']['id']).to eq(post.id)
    expect(payload['next_cursor']).to be_present
  end

  it 'returns unauthorized when the bearer token is missing or invalid' do
    get better_together.federation_content_feed_path(locale:)
    expect(response).to have_http_status(:unauthorized)

    get better_together.federation_content_feed_path(locale:),
        headers: { 'Authorization' => 'Bearer invalid-token' }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns forbidden when the connection lacks feed-read authorization' do
    issued_token = oauth_access_token

    connection.update!(
      federation_auth_policy: 'login_only',
      allow_content_read_scope: false
    )

    get better_together.federation_content_feed_path(locale:),
        headers: { 'Authorization' => "Bearer #{issued_token}" }

    expect(response).to have_http_status(:forbidden)
  end

  it 'rejects unrecognized bearer tokens' do
    get better_together.federation_content_feed_path(locale:),
        headers: { 'Authorization' => "Bearer #{SecureRandom.hex(32)}" }

    expect(response).to have_http_status(:unauthorized)
  end
end
