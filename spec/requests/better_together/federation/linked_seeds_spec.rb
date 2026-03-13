# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Federation::LinkedSeeds', :no_auth do
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
      allow_content_read_scope: true,
      allow_linked_content_read_scope: true
    )
  end
  let(:grant) do
    create(
      :better_together_person_access_grant,
      person_link: create(
        :better_together_person_link,
        platform_connection: connection,
        source_person: create(:better_together_person),
        target_person: create(:better_together_person)
      ),
      allow_private_posts: true
    )
  end
  let(:oauth_access_token) do
    BetterTogether::FederationAccessTokenIssuer.call(
      connection:,
      requested_scopes: 'linked_content.read'
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

    create(:better_together_post, creator: grant.grantor_person, privacy: 'private', platform: source_platform)

    host! source_hostname
  end

  after do
    source_platform.update_columns(host_url: 'http://www.example.com')
  end

  it 'returns recipient-scoped linked private seeds for an authorized peer' do
    get better_together.federation_linked_seeds_path(locale:),
        params: { recipient_identifier: grant.grantee_person.identifier },
        headers: { 'Authorization' => "Bearer #{oauth_access_token}" }

    expect(response).to have_http_status(:ok)

    payload = JSON.parse(response.body)
    expect(payload['seeds'].length).to eq(1)
    expect(payload['seeds'].first.dig('better_together', 'seed', 'origin', 'lane')).to eq('private_linked')
  end

  it 'returns forbidden without the linked-content scope' do
    token = BetterTogether::FederationAccessTokenIssuer.call(
      connection:,
      requested_scopes: 'content.read'
    ).access_token

    get better_together.federation_linked_seeds_path(locale:),
        params: { recipient_identifier: grant.grantee_person.identifier },
        headers: { 'Authorization' => "Bearer #{token}" }

    expect(response).to have_http_status(:forbidden)
  end
end
