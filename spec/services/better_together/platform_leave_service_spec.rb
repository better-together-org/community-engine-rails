# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformLeaveService do
  let!(:platform) { configure_host_platform }
  let(:member) { create(:better_together_user, :confirmed, platform:).person }
  let(:steward) { BetterTogether::Role.find_by!(identifier: 'platform_steward') }
  let(:viewer) { BetterTogether::Role.find_by!(identifier: 'platform_analytics_viewer') }

  def join(person, role)
    BetterTogether::PersonPlatformMembership.create!(member: person, joinable: platform, role:, status: 'active')
  end

  it 'removes the member platform memberships' do
    join(member, viewer)

    expect { described_class.call(person: member, platform:) }
      .to change(BetterTogether::PersonPlatformMembership, :count).by(-1)
  end

  it 'refuses when the person is the last steward' do
    BetterTogether::PersonPlatformMembership.where(joinable: platform, role: steward).destroy_all
    join(member, steward)

    expect { described_class.call(person: member, platform:) }.to raise_error(described_class::LastStewardError)
  end

  it 'allows a steward to leave when another steward remains' do
    join(member, steward)
    join(create(:better_together_user, :confirmed, platform:).person, steward)

    expect { described_class.call(person: member, platform:) }.not_to raise_error
  end
end
