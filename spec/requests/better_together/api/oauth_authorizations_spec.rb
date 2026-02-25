# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Doorkeeper authorization endpoint', :skip_host_setup do
  let(:locale) { I18n.default_locale }

  describe 'GET /api/oauth/authorize (authorization_code flow)' do
    let!(:oauth_app) do
      create(
        :better_together_oauth_application,
        name: 'Auth Code Test App',
        redirect_uri: 'https://example.com/callback',
        scopes: 'read',
        confidential: true
      )
    end

    it 'supports browser authorization flow requests' do
      get(
        "#{BetterTogether.route_scope_path}/api/oauth/authorize",
        params: {
          client_id: oauth_app.uid,
          redirect_uri: 'https://example.com/callback',
          response_type: 'code',
          scope: 'read',
          state: 'abc123'
        },
        headers: { 'ACCEPT' => 'text/html' }
      )

      expect(response).not_to have_http_status(:not_found)
      expect(response.media_type).to eq('text/html')
    end
  end
end
