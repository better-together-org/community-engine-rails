# frozen_string_literal: true

require 'rails_helper'

# Exercised through BetterTogether::PostPolicy (a concrete includer) rather
# than an anonymous double, to avoid divergence from real usage.
RSpec.describe BetterTogether::SelfServicePublishablePolicy do
  subject(:policy) { BetterTogether::PostPolicy.new(agent_user, record) }

  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:host_community) { host_platform.community }
  let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
  let(:agent_user) { create(:better_together_user, :confirmed) }
  let(:other_user) { create(:better_together_user, :confirmed) }
  let(:record) { BetterTogether::Post.new(community_id: host_community.id, creator: agent_user.person) }

  describe '#platform_manager?' do
    it 'is true for a manage_platform_settings holder' do
      allow(agent_user.person).to receive(:permitted_to?).with('manage_platform_settings', nil).and_return(true)
      allow(agent_user.person).to receive(:permitted_to?).with('manage_platform', nil).and_return(false)

      expect(policy.send(:platform_manager?)).to be true
    end

    it 'is true for a manage_platform holder' do
      allow(agent_user.person).to receive(:permitted_to?).with('manage_platform_settings', nil).and_return(false)
      allow(agent_user.person).to receive(:permitted_to?).with('manage_platform', nil).and_return(true)

      expect(policy.send(:platform_manager?)).to be true
    end

    it 'is false for a user with neither permission' do
      allow(agent_user.person).to receive(:permitted_to?).and_return(false)

      expect(policy.send(:platform_manager?)).to be false
    end
  end

  describe '#creator_of?' do
    it 'is true when the record was created by the agent' do
      expect(policy.send(:creator_of?, record)).to be true
    end

    it 'is false when the record was created by someone else' do
      other_record = BetterTogether::Post.new(community_id: host_community.id, creator: other_user.person)

      expect(policy.send(:creator_of?, other_record)).to be false
    end

    it 'is false when there is no agent' do
      anonymous_policy = BetterTogether::PostPolicy.new(nil, record)

      expect(anonymous_policy.send(:creator_of?, record)).to be false
    end
  end

  describe '#accepted_content_publishing_agreement?' do
    it 'is true once the agent has accepted the content publishing agreement' do
      grant_content_publishing_agreement(agent_user.person)

      expect(policy.send(:accepted_content_publishing_agreement?)).to be true
    end

    it 'is false when the agent has not accepted it' do
      expect(policy.send(:accepted_content_publishing_agreement?)).to be false
    end
  end

  describe '#self_service_content_creator?' do
    before do
      BetterTogether::PersonCommunityMembership.create!(
        joinable: host_community, member: agent_user.person, role: community_member_role, status: 'active'
      )
    end

    it 'is true when the agent is an active member of the resolved community and has accepted the agreement' do
      grant_content_publishing_agreement(agent_user.person)

      expect(policy.send(:self_service_content_creator?)).to be true
    end

    it 'is false when the agent has not accepted the agreement' do
      expect(policy.send(:self_service_content_creator?)).to be false
    end

    it 'is false when the resolved community is blank' do
      expect(policy.send(:self_service_content_creator?, community: nil)).to be false
    end

    it 'is false when there is no user' do
      anonymous_policy = BetterTogether::PostPolicy.new(nil, record)

      expect(anonymous_policy.send(:self_service_content_creator?)).to be false
    end
  end
end
