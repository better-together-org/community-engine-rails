# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Community do
  it 'exposes membership request settings as a permitted attribute' do
    expect(described_class.extra_permitted_attributes).to include(:allow_membership_requests)
    expect(described_class.extra_permitted_attributes).to include(:requires_invitation)
  end

  it 'defaults to invitation-only access' do
    community = build(:better_together_community)

    expect(community.access_mode).to eq(:invitation)
    expect(community.invitation_only?).to be(true)
  end

  it 'switches to open join when invitation requirement is turned off' do
    community = build(:better_together_community, :open_access)

    expect(community.access_mode).to eq(:open)
    expect(community.allows_direct_join?).to be(true)
  end

  it 'switches to request mode when membership requests are enabled and invitations are off' do
    community = create(:better_together_community, :membership_requests_enabled)
    platform = create(:better_together_platform, community:, allow_membership_requests: true)

    expect(community.membership_requests_enabled?(platform:)).to be(true)
    expect(community.access_mode).to eq(:request)
    expect(community.request_to_join_only?).to be(true)
    expect(community.self_service_membership_status).to eq('pending')
  end

  it 'keeps membership requests closed unless the community opts in' do
    community = create(:better_together_community, allow_membership_requests: false)
    platform = create(:better_together_platform, community:, allow_membership_requests: true)

    expect(community.membership_requests_enabled?(platform:)).to be(false)
    expect(community.access_mode).to eq(:invitation)
    expect(community.invitation_only?).to be(true)
  end

  it 'keeps membership requests closed unless the platform also opts in' do
    community = create(:better_together_community, allow_membership_requests: true)
    platform = create(:better_together_platform, community:, allow_membership_requests: false)

    expect(community.membership_requests_enabled?(platform:)).to be(false)
    expect(community.access_mode).to eq(:invitation)
    expect(community.invitation_only?).to be(true)
  end
end
