# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ConversationPolicy, type: :policy do
  include RequestSpecHelper

  let!(:host_platform) { configure_host_platform }
  let!(:other_platform) { create(:better_together_platform) }

  let!(:steward_user) { create(:user, :confirmed, password: 'SecureTest123!@#') }
  let!(:steward_person) { steward_user.person }

  let!(:opted_in_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true })
  end

  let!(:non_opted_person) { create(:better_together_person) }
  let!(:other_platform_opted_in_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true })
  end
  let!(:host_only_opted_in_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true })
  end

  before do
    manage_platform_permission = BetterTogether::ResourcePermission.find_by(identifier: 'manage_platform')
    steward_role = create(:better_together_role, :platform_role)
    BetterTogether::RoleResourcePermission.create!(role: steward_role, resource_permission: manage_platform_permission)
    create(:better_together_person_platform_membership, member: steward_person, joinable: host_platform, role: steward_role)
    create(:better_together_person_platform_membership, member: opted_in_person, joinable: host_platform)
    create(:better_together_person_platform_membership, member: non_opted_person, joinable: host_platform)
    create(:better_together_person_platform_membership, member: other_platform_opted_in_person, joinable: other_platform)
    create(:better_together_person_community_membership, member: host_only_opted_in_person, joinable: host_platform.community)
  end

  describe '#permitted_participants' do
    context 'when agent is a platform steward' do
      it 'includes only people on the current platform' do
        policy = described_class.new(steward_user, BetterTogether::Conversation.new)
        ids = policy.permitted_participants.pluck(:id)
        expect(ids).to include(steward_person.id, opted_in_person.id, non_opted_person.id, host_only_opted_in_person.id)
        expect(ids).not_to include(other_platform_opted_in_person.id)
      end
    end

    context 'when agent is a regular member' do
      let!(:regular_user) { create(:user, :confirmed, password: 'SecureTest123!@#') }

      before do
        create(:better_together_person_platform_membership, member: regular_user.person, joinable: host_platform)
      end

      it 'includes current-platform stewards and opted-in members, but not others' do
        # rubocop:enable RSpec/MultipleExpectations
        policy = described_class.new(regular_user, BetterTogether::Conversation.new)
        people = policy.permitted_participants
        expect(people).to include(steward_person, opted_in_person, host_only_opted_in_person)
        expect(people).not_to include(non_opted_person)
        expect(people).not_to include(other_platform_opted_in_person)
      end
    end
  end

  describe '#create? with participants kwarg' do
    let(:regular_user) { create(:user, :confirmed, password: 'SecureTest123!@#') }
    let(:policy) { described_class.new(regular_user, BetterTogether::Conversation.new) }

    before do
      create(:better_together_person_platform_membership, member: regular_user.person, joinable: host_platform)
    end

    it 'allows create when user present and participants are permitted' do
      # opted_in_person should be allowed for regular users
      expect(policy.create?(participants: [opted_in_person])).to be true
    end

    it 'allows create with a host-community recipient who opted in' do
      expect(policy.create?(participants: [host_only_opted_in_person])).to be true
    end

    it 'denies create when any participant is not permitted' do
      expect(policy.create?(participants: [non_opted_person])).to be false
    end

    it 'denies create when the participant is opted in on another platform only' do
      expect(policy.create?(participants: [other_platform_opted_in_person])).to be false
    end

    it 'defaults to basic presence check when participants nil' do
      expect(policy.create?).to be true
    end
  end
end
