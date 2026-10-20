# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AgentGrant do
  let(:platform) { BetterTogether::Platform.find_by!(host: true) }
  let(:operator) { create(:better_together_user, :confirmed, :platform_manager).person }
  let(:robot) { create(:robot, platform: platform) }

  it 'is active until revoked or expired' do
    grant = create(:better_together_agent_grant, robot: robot, operator: operator, platform: platform)
    expect(described_class.active).to include(grant)

    grant.update!(revoked_at: Time.current)
    expect(described_class.active).not_to include(grant)
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
