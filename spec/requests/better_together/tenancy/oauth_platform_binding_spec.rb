# frozen_string_literal: true

require 'rails_helper'

# P0-3: OAuth applications and tokens work only on the platform they were registered for.
RSpec.describe 'OAuth platform binding', :no_auth, :skip_host_setup do
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
  let(:manager_role) { BetterTogether::Role.find_by!(identifier: 'platform_manager') }
  let(:tenant_owner) { manager_of(tenant_platform) }
  let(:tenant_app) do
    create(:better_together_oauth_application, owner: tenant_owner, platform: tenant_platform)
  end

  def manager_of(platform)
    user = create(:better_together_user, :confirmed)
    BetterTogether::PersonPlatformMembership.create!(member: user.person, joinable: platform,
                                                     role: manager_role, status: 'active')
    user.person.expire_permission_cache!
    user.person
  end

  def token_for(application)
    create(:better_together_oauth_access_token, application:, resource_owner: application.owner.user,
                                                scopes: 'read')
  end

  it 'never treats a tenant manager application as trusted' do
    Current.set(platform: tenant_platform, host_platform:) do
      expect(tenant_app).not_to be_trusted
    end
  end

  it 'treats a host manager application on the host platform as trusted' do
    app = create(:better_together_oauth_application, owner: manager_of(host_platform), platform: host_platform)

    Current.set(platform: host_platform, host_platform:) { expect(app).to be_trusted }
  end

  it 'is not usable on another platform' do
    expect(tenant_app.usable_on?(tenant_platform)).to be(true)
    expect(tenant_app.usable_on?(host_platform)).to be(false)
  end

  it 'rejects a tenant application token on the host domain' do
    host! 'host.example.test'
    get '/api/v1/communities', headers: { 'Authorization' => "Bearer #{token_for(tenant_app).token}",
                                          'Accept' => 'application/vnd.api+json' }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'accepts the same token on its own platform' do
    host! 'tenant.example.test'
    get '/api/v1/communities', headers: { 'Authorization' => "Bearer #{token_for(tenant_app).token}",
                                          'Accept' => 'application/vnd.api+json' }

    expect(response).to have_http_status(:ok)
  end
end
