# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Baseline platform membership at registration', :no_auth, :skip_host_setup do
  include AutomaticTestConfiguration

  let!(:platform) do
    configure_host_platform.tap { |host| host.update!(requires_invitation: false) }
  end

  let(:suffix) { SecureRandom.hex(4) }
  let(:email) { "newcomer-#{suffix}@example.com" }

  before do
    %w[privacy_policy terms_of_service code_of_conduct].each do |identifier|
      BetterTogether::Agreement.find_or_create_by(identifier:) do |agreement|
        agreement.title = identifier.titleize
        agreement.creator = create(:better_together_person)
      end
    end
  end

  def register
    challenge = travel_to(3.seconds.ago) { BetterTogether::BotDefense::Challenge.issue(form_id: :registration) }
    post '/en/users', params: {
      user: {
        email:, password: 'SecureTest123!@#', password_confirmation: 'SecureTest123!@#',
        person_attributes: { name: 'Newcomer', identifier: "newcomer-#{suffix}" }
      },
      terms_of_service_agreement: '1', privacy_policy_agreement: '1', code_of_conduct_agreement: '1',
      bot_defense: { token: challenge.token, trap_values: { challenge.trap_field => '' } }
    }
  end

  it 'gives a new account the platform_member role on its platform, pending until the address is confirmed' do
    expect { register }.to change(BetterTogether::User, :count).by(1)

    person = BetterTogether::User.find_by!(email:).person
    member_role = BetterTogether::Role.find_default('platform_member', platform:)
    expect(platform.person_platform_memberships.find_by(member: person))
      .to have_attributes(role: member_role, status: 'pending')
  end

  it 'keeps a platform invitation role and adds the baseline beside it' do
    steward = BetterTogether::Role.find_default('platform_steward', platform:)
    invitation = create(:better_together_platform_invitation, invitable: platform, invitee_email: email,
                                                              platform_role: steward, status: 'pending')

    post '/en/users', params: {
      user: {
        email:, password: 'SecureTest123!@#', password_confirmation: 'SecureTest123!@#',
        person_attributes: { name: 'Newcomer', identifier: "newcomer-#{suffix}" }
      },
      invitation_code: invitation.token,
      terms_of_service_agreement: '1', privacy_policy_agreement: '1', code_of_conduct_agreement: '1',
      bot_defense: begin
        challenge = travel_to(3.seconds.ago) { BetterTogether::BotDefense::Challenge.issue(form_id: :registration) }
        { token: challenge.token, trap_values: { challenge.trap_field => '' } }
      end
    }

    person = BetterTogether::User.find_by!(email:).person
    memberships = platform.person_platform_memberships.where(member: person)
    expect(memberships.map { |m| m.role.identifier }).to contain_exactly('platform_steward', 'platform_member')
    expect(memberships.find_by(role: steward)).to be_active
  end
end
