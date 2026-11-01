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

  describe 'integrity' do
    it 'rejects a robot that belongs to another platform' do
      other_robot = create(:robot, platform: create(:better_together_platform))
      grant = build(:better_together_agent_grant, robot: other_robot, operator: operator, platform: platform)

      expect(grant).not_to be_valid
      expect(grant.errors[:robot]).to be_present
    end

    it 'rejects a community from another platform' do
      community = create(:better_together_community, platform: create(:better_together_platform))
      grant = build(:better_together_agent_grant, robot: robot, operator: operator, platform: platform,
                                                  community: community)

      expect(grant).not_to be_valid
      expect(grant.errors[:community]).to be_present
    end

    it 'rejects a grantor without the authority being delegated' do
      grantor = create(:better_together_user, :confirmed).person
      grant = build(:better_together_agent_grant, robot: robot, operator: operator, platform: platform,
                                                  granted_by: grantor, scopes: %w[read admin])

      expect(grant).not_to be_valid
      expect(grant.errors[:scopes].join).to include('granted_by')
    end

    it 'allows only one open grant per robot, platform and community' do
      create(:better_together_agent_grant, robot: robot, operator: operator, platform: platform)
      duplicate = build(:better_together_agent_grant, robot: robot, operator: operator, platform: platform)

      expect(duplicate).not_to be_valid
    end

    it 'enforces the same rule in the database' do
      create(:better_together_agent_grant, robot: robot, operator: operator, platform: platform)
      duplicate = build(:better_together_agent_grant, robot: robot, operator: operator, platform: platform)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows a new grant once the previous one is revoked' do
      create(:better_together_agent_grant, robot: robot, operator: operator, platform: platform).revoke!

      expect(build(:better_together_agent_grant, robot: robot, operator: operator, platform: platform)).to be_valid
    end
  end
end
