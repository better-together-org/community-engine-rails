# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Community do
  it 'exposes membership request settings as a permitted attribute' do
    expect(described_class.extra_permitted_attributes).to include(:allow_membership_requests)
  end

  it 'defaults to open join' do
    community = build(:better_together_community)

    expect(community.access_mode).to eq(:open)
    expect(community.allows_direct_join?).to be(true)
  end

  it 'switches to request mode when membership requests are enabled' do
    community = build(:better_together_community, :membership_requests_enabled)

    expect(community.access_mode).to eq(:request)
    expect(community.request_to_join_only?).to be(true)
    expect(community.self_service_membership_status).to eq('pending')
  end
end
