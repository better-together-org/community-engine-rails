# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/person_platform_integrations/_integrations_list' do
  let!(:platform) { configure_host_platform }
  let(:domain) { ensure_host_platform_domain(platform) }

  before { view.extend BetterTogether::OauthButtonsHelper }

  context 'with an environment-configured provider' do
    before do
      domain
      stub_provider_env('GITHUB_CLIENT_ID', 'GITHUB_CLIENT_SECRET')
      allow(view).to receive(:omniauth_authorize_path) { |_scope, provider| "/users/auth/#{provider}" }
    end

    it 'offers only providers configured for this domain', :aggregate_failures do
      render partial: 'better_together/person_platform_integrations/integrations_list',
             locals: { person_platform_integrations: [] }

      expect(rendered).to include('/users/auth/github')
      expect(rendered).not_to include('/users/auth/google_oauth2')
      expect(rendered).not_to include('/users/auth/facebook')
      expect(rendered).not_to include('/users/auth/openid_connect')
    end
  end

  context 'with several OpenID Connect issuers' do
    before do
      allow(view).to receive(:request).and_return(double(env: Rack::MockRequest.env_for("https://#{domain.hostname}/")))
    end

    def oidc(issuer, **attrs)
      create(:better_together_platform_identity_provider, platform:, strategy: 'openid_connect',
                                                          provider_platform: nil, issuer:, **attrs)
        .tap { |row| row.update!(platform_domains: [domain]) }
    end

    it 'offers a connect button for each configured issuer', :aggregate_failures do
      one = oidc('https://idp.one.example.org', label: 'Co-op login')
      two = oidc('https://idp.two.example.org')

      render partial: 'better_together/person_platform_integrations/integrations_list',
             locals: { person_platform_integrations: [] }

      expect(rendered).to include("connect-openid_connect-#{one.id}", "connect-openid_connect-#{two.id}", 'Co-op login')
    end

    it 'does not offer an issuer that is already connected', :aggregate_failures do
      one = oidc('https://idp.one.example.org')
      two = oidc('https://idp.two.example.org')
      connected = create(:person_platform_integration, provider: 'openid_connect', platform: one.provider_platform)

      render partial: 'better_together/person_platform_integrations/integrations_list',
             locals: { person_platform_integrations: [connected] }

      expect(rendered).not_to include("connect-openid_connect-#{one.id}")
      expect(rendered).to include("connect-openid_connect-#{two.id}")
    end
  end
end
