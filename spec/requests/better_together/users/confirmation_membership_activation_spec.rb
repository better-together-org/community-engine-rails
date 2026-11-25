# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Membership activation on email confirmation', :no_auth, :skip_host_setup do
  include AutomaticTestConfiguration

  let!(:platform) { configure_host_platform }
  let(:community) { platform.primary_community }
  let(:user) do
    create(:better_together_user, platform:).tap do |u|
      u.update_columns(confirmed_at: nil, confirmation_token: SecureRandom.hex(10))
    end
  end
  let(:person) { user.person }

  def confirm
    get "/en/users/confirmation?confirmation_token=#{user.confirmation_token}"
  end

  it 'activates the baseline platform membership' do
    role = BetterTogether::Role.find_default('platform_member', platform:)
    membership = platform.person_platform_memberships.create!(member: person, role:, status: 'pending')

    confirm

    expect(membership.reload.status).to eq('active')
  end

  it 'leaves an elevated platform membership pending' do
    role = BetterTogether::Role.find_default('platform_steward', platform:)
    membership = platform.person_platform_memberships.create!(member: person, role:, status: 'pending')

    confirm

    expect(membership.reload.status).to eq('pending')
  end

  it 'leaves a community membership pending when the community reviews requests' do
    platform.update!(allow_membership_requests: true)
    community.update!(allow_membership_requests: true)
    role = BetterTogether::Role.find_default('community_member', platform:)
    membership = community.person_community_memberships.create!(member: person, role:, status: 'pending')

    confirm

    expect(membership.reload.status).to eq('pending')
  end

  it 'activates a community membership when no approval is needed' do
    role = BetterTogether::Role.find_default('community_member', platform:)
    membership = community.person_community_memberships.create!(member: person, role:, status: 'pending')
    platform.update!(allow_membership_requests: false)

    confirm

    expect(membership.reload.status).to eq('active')
  end
end
