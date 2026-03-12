# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Federation::ContentFeed', :no_auth do
  let(:locale) { I18n.default_locale }
  let(:source_platform) { create(:better_together_platform, host: true) }
  let(:source_domain) { create(:better_together_platform_domain, platform: source_platform, domain: 'source.example.test', primary: true) }
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

  before do
    source_domain
    host! 'source.example.test'
  end

  it 'returns a cursor-paginated content batch for an authorized peer' do
    post = create(:better_together_post, platform: source_platform, privacy: 'public', published_at: 1.day.ago)

    get better_together.federation_content_feed_path(locale:),
        headers: { 'Authorization' => "Bearer #{connection.federation_access_token}" }

    expect(response).to have_http_status(:ok)

    payload = JSON.parse(response.body)
    expect(payload['items'].first['type']).to eq('post')
    expect(payload['items'].first['id']).to eq(post.id)
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
    connection.update!(
      federation_auth_policy: 'login_only',
      allow_content_read_scope: false
    )

    get better_together.federation_content_feed_path(locale:),
        headers: { 'Authorization' => "Bearer #{connection.federation_access_token}" }

    expect(response).to have_http_status(:forbidden)
  end
end
