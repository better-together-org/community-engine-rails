# frozen_string_literal: true

require 'rails_helper'

# P0-1: an invitation token is only redeemable on the platform that issued it.
RSpec.describe 'Invitation tokens are bound to their platform', :no_auth, :skip_host_setup do
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
  let(:steward_role) { BetterTogether::Role.find_by(identifier: 'platform_steward') || create(:role, :platform_role, identifier: 'platform_steward') }
  let(:inviter) { create(:better_together_person) }
  let!(:invitation) do
    create(:better_together_platform_invitation,
           invitable: tenant_platform, inviter:, platform_role: steward_role, locale: 'en')
  end

  before { host_platform.update!(requires_invitation: true) }

  def host_memberships
    BetterTogether::PersonPlatformMembership.where(joinable: host_platform, role: steward_role)
  end

  def sign_up_params(email)
    challenge = travel_to(3.seconds.ago) { BetterTogether::BotDefense::Challenge.issue(form_id: :registration) }
    { user: { email:, password: 'SecureTest123!@#', password_confirmation: 'SecureTest123!@#',
              person_attributes: { name: 'Mallory', identifier: "mallory-#{SecureRandom.hex(3)}" } },
      terms_of_service_agreement: '1', privacy_policy_agreement: '1', code_of_conduct_agreement: '1',
      invitation_code: invitation.token,
      bot_defense: { token: challenge.token, trap_values: { challenge.trap_field => '' } } }
  end

  it 'refuses a tenant invitation redeemed on the host domain and creates nothing' do
    host! 'host.example.test'
    host_before = host_memberships.count

    expect { post '/en/users', params: sign_up_params('mallory@example.com') }
      .not_to change(BetterTogether::User, :count)
    expect(host_memberships.count).to eq(host_before)
    expect(invitation.reload).to be_status_pending
  end

  it 'does not pick the invitation up from the query string on another platform' do
    host! 'host.example.test'
    get "/en/users/sign-up?invitation_code=#{invitation.token}"

    expect(session[:platform_invitation_token]).to be_nil
  end

  it 'still redeems on the issuing platform and grants the role there only' do
    host! 'tenant.example.test'
    host_before = host_memberships.count

    expect { post '/en/users', params: sign_up_params('steward@example.com') }
      .to change(BetterTogether::User, :count).by(1)
    expect(BetterTogether::PersonPlatformMembership.where(joinable: tenant_platform, role: steward_role)).to exist
    expect(host_memberships.count).to eq(host_before)
  end

  it 'rejects a platform invitation carrying a non platform role' do
    community_role = create(:role, :community_role)
    bad = build(:better_together_platform_invitation, invitable: tenant_platform, inviter:, platform_role: community_role)

    expect(bad).not_to be_valid
    expect(bad.errors[:platform_role]).to be_present
  end
end
