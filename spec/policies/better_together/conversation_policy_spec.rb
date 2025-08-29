# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ConversationPolicy, type: :policy do
  include RequestSpecHelper

  let!(:host_platform) { configure_host_platform }

  let!(:manager_user) { create(:user, :confirmed, :platform_manager, password: 'password12345') }
  let!(:manager_person) { manager_user.person }

  let!(:opted_in_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true })
  end

  let!(:non_opted_person) { create(:better_together_person) }

  describe '#permitted_participants' do
    context 'when agent is a platform manager' do
      it 'includes all people' do
        policy = described_class.new(manager_user, BetterTogether::Conversation.new)
        ids = policy.permitted_participants.pluck(:id)
        expect(ids).to include(manager_person.id, opted_in_person.id, non_opted_person.id)
      end
    end

    context 'when agent is a regular member' do
      let!(:regular_user) { create(:user, :confirmed, password: 'password12345') }

      it 'includes platform managers and opted-in members, but not non-opted members' do
        policy = described_class.new(regular_user, BetterTogether::Conversation.new)
        people = policy.permitted_participants
        expect(people).to include(manager_person, opted_in_person)
        expect(people).not_to include(non_opted_person)
      end
    end
  end
end
