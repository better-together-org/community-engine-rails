# frozen_string_literal: true

require 'rails_helper'

# P0-5: a hosted platform's manager cannot create OpenID Connect issuers or trust their email claims.
RSpec.describe 'OIDC issuer administration is host only', :no_auth, :skip_host_setup do
  let!(:host_platform) { configure_host_platform }
  let(:tenant_platform) { create(:better_together_platform, :public) }
  let(:manager_role) { BetterTogether::Role.find_by!(identifier: 'platform_manager') }
  let(:tenant_manager) do
    user = create(:better_together_user, :confirmed, password: 'SecureTest123!@#')
    BetterTogether::PersonPlatformMembership.create!(member: user.person, joinable: tenant_platform,
                                                     role: manager_role, status: 'active')
    user.person.expire_permission_cache!
    user
  end
  let(:params) do
    { platform_identity_provider: { strategy: 'openid_connect', client_id: 'cid', client_secret: 'sec',
                                    issuer: 'https://idp.example.org', trust_verified_email: '1' } }
  end

  before do
    allow(Resolv).to receive(:getaddresses).and_call_original
    allow(Resolv).to receive(:getaddresses).with('idp.example.org').and_return(['93.184.216.34'])
  end

  # The /host routes are gated to host managers (P0-2); the controller also drops the issuer
  # and trust params for any non-host actor as defence in depth.
  it 'creates no issuer-based provider for a tenant manager' do
    sign_in tenant_manager
    expect do
      post "/#{I18n.default_locale}/host/platforms/#{tenant_platform.to_param}/identity_providers", params:
    rescue ActionController::RoutingError
      nil
    end.not_to change(BetterTogether::PlatformIdentityProvider.where(strategy: 'openid_connect'), :count)
  end
end
