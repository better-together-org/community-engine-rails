# frozen_string_literal: true

require 'rails_helper'

# P0-6: a JWT issued on one platform is rejected on every other platform.
RSpec.describe 'JWT platform audience', :no_auth, :skip_host_setup do
  let!(:host_platform) { configure_host_platform }
  let!(:host_domain) do
    BetterTogether::PlatformDomain.find_by(platform: host_platform, primary_flag: true) ||
      create(:better_together_platform_domain, :primary, platform: host_platform, hostname: 'host.example.test')
  end
  let(:tenant_platform) { create(:better_together_platform, :public) }
  let!(:tenant_domain) do
    domain = BetterTogether::PlatformDomain.find_by(platform: tenant_platform, primary_flag: true) ||
             create(:better_together_platform_domain, :primary, platform: tenant_platform)
    domain.update!(hostname: 'tenant.example.test')
    domain
  end
  let(:user) { create(:better_together_user, :confirmed, password: 'SecureTest123!@#') }
  let(:headers) { { 'Accept' => 'application/vnd.api+json' } }

  def issue_token_on(hostname)
    host! hostname
    post '/api/auth/sign-in', params: { user: { email: user.email, password: 'SecureTest123!@#' } }, as: :json
    response.headers['Authorization']
  end

  def decode(bearer)
    JWT.decode(bearer.delete_prefix('Bearer '), nil, false).first
  end

  it 'embeds the issuing platform in the token' do
    token = issue_token_on('host.example.test')

    expect(decode(token)['plt']).to eq(host_platform.id)
  end

  it 'accepts the token on the platform that issued it' do
    token = issue_token_on('host.example.test')
    get '/api/v1/communities', headers: headers.merge('Authorization' => token)

    expect(response).to have_http_status(:ok)
  end

  it 'rejects the token on another platform' do
    token = issue_token_on('host.example.test')
    host! 'tenant.example.test'
    get '/api/v1/communities', headers: headers.merge('Authorization' => token)

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a token that carries no platform claim' do
    legacy, = Warden::JWTAuth::UserEncoder.new.call(user, :api_user, 'aud')
    host! 'host.example.test'
    get '/api/v1/communities', headers: headers.merge('Authorization' => "Bearer #{legacy}")

    expect(response).to have_http_status(:unauthorized)
  end
end
