# frozen_string_literal: true

require 'rails_helper'

# GHSA-m27g-v28p-f9fx: the OAuth callback URL must not be built from a forged Host header.
RSpec.describe 'OmniAuth GitHub request phase host handling', :no_auth do
  before do
    ensure_host_platform_domain(configure_host_platform)
    stub_provider_env('GITHUB_CLIENT_ID', 'GITHUB_CLIENT_SECRET')
  end

  it 'does not send a forged Host or X-Forwarded-Host to the OAuth callback URL' do
    post '/users/auth/github',
         headers: { 'HOST' => 'evil.example.com', 'X-Forwarded-Host' => 'evil.example.com' }

    expect(response).to have_http_status(:found)
    expect(response.location).to include('/users/auth/github/callback')
    expect(response.location).not_to include('evil.example.com')
  end
end
