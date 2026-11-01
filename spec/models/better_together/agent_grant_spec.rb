# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AgentGrant do
  let(:platform) { BetterTogether::Platform.find_by!(host: true) }
  let(:operator) { create(:better_together_user, :confirmed, :platform_manager).person }
  let(:robot) { create(:robot, platform: platform) }

  it 'is active until revoked or expired' do
    grant = create(:better_together_agent_grant, robot: robot, operator: operator, platform: platform)
    expect(described_class.active).to include(grant)

    grant.revoke!
    expect(described_class.active).not_to include(grant)
  end

  it 'can be revoked after its operator loses platform authority' do
    grant = create(:better_together_agent_grant, robot: robot, operator: operator, platform: platform,
                                                 scopes: %w[read admin])
    operator.person_platform_memberships.destroy_all

    expect { grant.reload.revoke! }.not_to raise_error
    expect(grant.reload).not_to be_active
  end

  it 'still validates scope changes for a demoted operator' do
    grant = create(:better_together_agent_grant, robot: robot, operator: operator, platform: platform,
                                                 scopes: %w[read])
    operator.person_platform_memberships.destroy_all
    grant.reload.scopes = %w[read admin]

    expect(grant).not_to be_valid
  end

  it 'rejects unknown scopes' do
    grant = build(:better_together_agent_grant, robot: robot, operator: operator, platform: platform,
                                                scopes: %w[bogus])

    expect(grant).not_to be_valid
  end

  it 'requires a platform' do
    grant = build(:better_together_agent_grant, robot: robot, operator: operator, platform: nil)

    expect(grant).not_to be_valid
  end
end
