# frozen_string_literal: true

require 'rails_helper'

# Google sign-in on an invitation-only platform: a verified address on a trusted domain gets in without an
# invitation and joins the community with the domain's role; everyone else is refused.
RSpec.describe BetterTogether::Users::OmniauthCallbacksController, :no_auth, :omniauth do
  routes { BetterTogether::Engine.routes }

  include Devise::Test::ControllerHelpers

  let!(:platform) { configure_host_platform }
  let(:community) { platform.community }
  let(:email) { "member-#{SecureRandom.hex(4)}@trusted.example" }
  let(:email_verified) { true }
  let(:member_role) { BetterTogether::Role.find_by!(identifier: 'community_member') }
  let(:contributor_role) { BetterTogether::Role.find_by!(identifier: 'community_contributor') }
  let(:trusted_role) { member_role }
  let(:include_subdomains) { false }
  let(:google_auth) do
    OmniAuth::AuthHash.new(
      provider: 'google_oauth2', uid: "g-#{SecureRandom.hex(6)}",
      info: { email:, name: 'Board Member', email_verified: },
      credentials: { token: 'tok', expires_at: 1.hour.from_now.to_i }
    )
  end

  before do
    BetterTogether::Platform.find_or_create_by!(identifier: 'google') do |google|
      google.external = true
      google.host = false
      google.name = 'Google'
      google.url = 'https://accounts.google.com'
      google.privacy = 'public'
      google.time_zone = 'UTC'
    end
    platform.update!(requires_invitation: true)
    create(:platform_trusted_domain, platform:, domain: 'trusted.example', role: trusted_role,
                                     role_ceiling_confirmed: true, include_subdomains:)
    request.host = 'localhost'
    @request.env['devise.mapping'] = Devise.mappings[:user] # rubocop:todo RSpec/InstanceVariable
    request.env['omniauth.auth'] = google_auth
  end

  def membership_for(address)
    user = BetterTogether.user_class.find_by!(email: address)
    community.person_community_memberships.find_by(member: user.person)
  end

  context 'with a verified address on a trusted domain' do
    it 'creates the account, signs in and grants the basic member role', :aggregate_failures do
      expect { get :google_oauth2 }.to change(BetterTogether.user_class, :count).by(1)

      expect(controller.current_user.email).to eq(email)
      expect(membership_for(email)).to have_attributes(role: member_role, status: 'active')
    end

    it 'writes an audit entry', :aggregate_failures do
      get :google_oauth2

      event = BetterTogether::TrustedDomainEvent.last
      expect(event).to have_attributes(event_type: 'account_created', domain: 'trusted.example', via: 'oauth',
                                       role_identifier: 'community_member', platform_id: platform.id)
      expect(event.subject).to eq(BetterTogether.user_class.find_by!(email:).person)
    end

    context 'when the domain grants a confirmed higher role' do
      let(:trusted_role) { contributor_role }

      it 'uses the domain role' do
        get :google_oauth2

        expect(membership_for(email).role).to eq(contributor_role)
      end
    end
  end

  context 'with an address on an untrusted domain' do
    let(:email) { "someone-#{SecureRandom.hex(4)}@elsewhere.example" }

    it 'is refused and creates nothing', :aggregate_failures do
      expect { get :google_oauth2 }.not_to change(BetterTogether.user_class, :count)

      expect(flash[:alert]).to match(/invitation.*required/i)
      expect(BetterTogether::TrustedDomainEvent.count).to eq(0)
    end
  end

  context 'when Google does not vouch for the email' do
    let(:email_verified) { false }

    it 'is refused even on a trusted domain', :aggregate_failures do
      expect { get :google_oauth2 }.not_to change(BetterTogether.user_class, :count)

      expect(flash[:alert]).to match(/invitation.*required/i)
    end
  end

  context 'with a subdomain of a trusted domain' do
    let(:email) { "member-#{SecureRandom.hex(4)}@mail.trusted.example" }

    it 'is refused unless subdomains are enabled' do
      expect { get :google_oauth2 }.not_to change(BetterTogether.user_class, :count)
    end

    context 'when the domain includes subdomains' do
      let(:include_subdomains) { true }

      it 'is accepted' do
        expect { get :google_oauth2 }.to change(BetterTogether.user_class, :count).by(1)
      end
    end
  end

  context 'when the platform is open to everyone' do
    let(:email) { "someone-#{SecureRandom.hex(4)}@elsewhere.example" }

    it 'does not record a trusted-domain grant', :aggregate_failures do
      platform.update!(requires_invitation: false)

      expect { get :google_oauth2 }.to change(BetterTogether.user_class, :count).by(1)
      expect(BetterTogether::TrustedDomainEvent.count).to eq(0)
    end
  end

  context 'with an invitation in the session' do
    let(:invitation) do
      create(:better_together_platform_invitation, invitable: platform, invitee_email: email, status: 'pending')
    end

    before do
      session[:platform_invitation_token] = invitation.token
      session[:platform_invitation_expires_at] = 1.hour.from_now
    end

    it 'lets the invitation win: no trusted-domain grant is recorded', :aggregate_failures do
      expect { get :google_oauth2 }.to change(BetterTogether.user_class, :count).by(1)
      expect(BetterTogether::TrustedDomainEvent.count).to eq(0)
    end
  end

  context 'when another platform trusts the domain' do
    it 'does not apply to this platform', :aggregate_failures do
      BetterTogether::PlatformTrustedDomain.where(platform:).delete_all
      create(:platform_trusted_domain, platform: create(:better_together_platform), domain: 'trusted.example')

      expect { get :google_oauth2 }.not_to change(BetterTogether.user_class, :count)
    end
  end
end
