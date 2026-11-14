# frozen_string_literal: true

require 'rails_helper'

# Email and password sign-up on an invitation-only platform with a trusted domain: the account is created
# unconfirmed, and membership is only granted once the address is confirmed.
RSpec.describe 'Trusted domain registration', :no_auth, :skip_host_setup do
  include AutomaticTestConfiguration

  let!(:platform) do
    configure_host_platform.tap { |host| host.update!(requires_invitation: true) }
  end
  let(:community) { platform.community }
  let(:email) { "board-#{SecureRandom.hex(4)}@trusted.example" }
  let(:user_params) do
    { email:, password: 'SecureTest123!@#', password_confirmation: 'SecureTest123!@#',
      person_attributes: { name: 'Board Member', identifier: "board-#{SecureRandom.hex(4)}" } }
  end
  let(:contributor_role) { BetterTogether::Role.find_by!(identifier: 'community_contributor') }
  let(:member_role) { BetterTogether::Role.find_by!(identifier: 'community_member') }
  let(:domain_role) { member_role }

  before do
    %w[privacy_policy terms_of_service code_of_conduct].each do |identifier|
      BetterTogether::Agreement.find_or_create_by(identifier:) do |agreement|
        agreement.title = identifier.humanize
        agreement.creator = create(:better_together_person)
      end
    end
    create(:platform_trusted_domain, platform:, domain: 'trusted.example', role: domain_role,
                                     role_ceiling_confirmed: true)
  end

  def bot_defense_payload
    challenge = travel_to(3.seconds.ago) { BetterTogether::BotDefense::Challenge.issue(form_id: :registration) }
    { bot_defense: { token: challenge.token, trap_values: { challenge.trap_field => '' } } }
  end

  def register(params: user_params, invitation_code: nil)
    body = { user: params, terms_of_service_agreement: '1', privacy_policy_agreement: '1',
             code_of_conduct_agreement: '1' }.merge(bot_defense_payload)
    body[:invitation_code] = invitation_code if invitation_code
    post '/en/users', params: body
  end

  def membership_for(user)
    community.person_community_memberships.find_by(member: user.person)
  end

  context 'with an address on a trusted domain' do
    it 'creates an unconfirmed account with a pending membership and no access', :aggregate_failures do
      expect { register }.to change(BetterTogether::User, :count).by(1)

      user = BetterTogether::User.find_by!(email:)
      expect(user).not_to be_confirmed
      expect(membership_for(user)).to have_attributes(status: 'pending', role: member_role)
    end

    it 'audits the account creation as unverified' do
      register

      expect(BetterTogether::TrustedDomainEvent.last).to have_attributes(
        event_type: 'account_created', via: 'password_registration', domain: 'trusted.example'
      )
    end

    it 'activates the membership when the address is confirmed', :aggregate_failures do
      register
      user = BetterTogether::User.find_by!(email:)

      user.confirm

      expect(membership_for(user)).to have_attributes(status: 'active', role: member_role)
      expect(BetterTogether::TrustedDomainEvent.last).to have_attributes(event_type: 'membership_granted')
    end

    context 'when the domain grants a higher, confirmed role' do
      let(:domain_role) { contributor_role }

      it 'holds the role pending, then grants it only after confirmation', :aggregate_failures do
        register
        user = BetterTogether::User.find_by!(email:)
        expect(membership_for(user)).to have_attributes(status: 'pending', role: contributor_role)

        user.confirm

        expect(membership_for(user)).to have_attributes(status: 'active', role: contributor_role)
      end
    end

    it 'does not grant anything to an address changed to another domain before confirmation', :aggregate_failures do
      register
      user = BetterTogether::User.find_by!(email:)
      user.update_columns(email: 'someone@untrusted.example') # rubocop:disable Rails/SkipsModelValidations

      user.confirm

      expect(membership_for(user)).to have_attributes(status: 'pending')
    end
  end

  context 'with an address on an untrusted domain' do
    let(:email) { "someone-#{SecureRandom.hex(4)}@elsewhere.example" }

    it 'is blocked as before', :aggregate_failures do
      expect { register }.not_to change(BetterTogether::User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context 'with a disabled trusted domain' do
    it 'is blocked' do
      BetterTogether::PlatformTrustedDomain.where(platform:).update_all(enabled: false) # rubocop:disable Rails/SkipsModelValidations

      expect { register }.not_to change(BetterTogether::User, :count)
    end
  end

  context 'with a valid platform invitation as well' do
    let!(:invitation) do
      create(:better_together_platform_invitation, invitable: platform, invitee_email: email, status: 'pending')
    end

    it 'lets the invitation win: active membership, no trusted domain audit', :aggregate_failures do
      expect { register(invitation_code: invitation.token) }.to change(BetterTogether::User, :count).by(1)

      expect(membership_for(BetterTogether::User.find_by!(email:))).to have_attributes(status: 'active')
      expect(BetterTogether::TrustedDomainEvent.count).to eq(0)
    end
  end
end
