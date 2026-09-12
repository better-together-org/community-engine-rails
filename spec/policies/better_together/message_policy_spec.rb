# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MessagePolicy, type: :policy do
  let(:sender_person) { create(:better_together_person) }
  let(:sender_user) { create(:better_together_user, person: sender_person) }

  let(:other_person) { create(:better_together_person) }
  let(:other_user) { create(:better_together_user, person: other_person) }

  let(:conversation) do
    create(:better_together_conversation, creator: sender_person)
  end

  let(:message) { create(:better_together_message, sender: sender_person, conversation:) }

  describe '#show?' do
    it 'allows a conversation participant to view messages' do
      expect(described_class.new(sender_user, message).show?).to be true
    end

    it 'denies users who are not conversation participants' do
      expect(described_class.new(other_user, message).show?).to be false
    end

    it 'denies guests' do
      expect(described_class.new(nil, message).show?).to be false
    end
  end

  describe '#create?' do
    it 'allows participants to create messages' do
      expect(described_class.new(sender_user, message).create?).to be true
    end

    it 'denies non-participants' do
      expect(described_class.new(other_user, message).create?).to be false
    end

    it 'denies guests' do
      expect(described_class.new(nil, message).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows the sender to update their message' do
      expect(described_class.new(sender_user, message).update?).to be true
    end

    it 'denies other participants from updating a message they did not send' do
      conversation.participants << other_person
      expect(described_class.new(other_user, message).update?).to be false
    end

    it 'denies guests' do
      expect(described_class.new(nil, message).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows the sender to destroy their message' do
      expect(described_class.new(sender_user, message).destroy?).to be true
    end

    it 'denies participants who are not the sender' do
      conversation.participants << other_person
      expect(described_class.new(other_user, message).destroy?).to be false
    end

    it 'denies guests' do
      expect(described_class.new(nil, message).destroy?).to be false
    end
  end
end
