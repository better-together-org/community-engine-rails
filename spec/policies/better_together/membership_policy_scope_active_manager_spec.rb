# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Membership policy scopes honour the manager membership status', type: :policy do # rubocop:disable RSpec/DescribeClass
  let(:platform) { configure_host_platform }
  let(:community) { platform.primary_community }
  let(:manager_user) { create(:better_together_user, :confirmed, platform:) }
  let(:manager) { manager_user.person }
  let(:other) { create(:better_together_person) }

  def role(identifier) = BetterTogether::Role.find_default(identifier, platform:)

  describe BetterTogether::PersonPlatformMembershipPolicy::Scope do
    let!(:others_membership) do
      platform.person_platform_memberships.create!(member: other, role: role('platform_member'), status: 'active')
    end

    it 'lets an active steward see other members' do
      platform.person_platform_memberships.create!(member: manager, role: role('platform_steward'), status: 'active')

      expect(described_class.new(manager_user, BetterTogether::PersonPlatformMembership.all).resolve)
        .to include(others_membership)
    end

    it 'does not let a pending steward see other members' do
      platform.person_platform_memberships.create!(member: manager, role: role('platform_steward'), status: 'pending')

      expect(described_class.new(manager_user, BetterTogether::PersonPlatformMembership.all).resolve)
        .not_to include(others_membership)
    end
  end

  describe BetterTogether::PersonCommunityMembershipPolicy::Scope do
    let!(:others_membership) do
      community.person_community_memberships.create!(member: other, role: role('community_member'), status: 'active')
    end

    it 'lets an active organizer see other members' do
      community.person_community_memberships.create!(member: manager, role: role('community_organizer'),
                                                     status: 'active')

      expect(described_class.new(manager_user, BetterTogether::PersonCommunityMembership.all).resolve)
        .to include(others_membership)
    end

    it 'does not let a pending organizer see other members' do
      community.person_community_memberships.create!(member: manager, role: role('community_organizer'),
                                                     status: 'pending')

      expect(described_class.new(manager_user, BetterTogether::PersonCommunityMembership.all).resolve)
        .not_to include(others_membership)
    end
  end
end
