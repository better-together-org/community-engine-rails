# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ConversationParticipant do
  describe 'factory' do
    it 'creates a valid conversation participant' do
      participant = build(:conversation_participant)
      expect(participant).to be_valid
    end

    it 'creates with custom conversation' do
      conversation = create(:conversation)
      participant = create(:conversation_participant, conversation: conversation)
      expect(participant.conversation).to eq(conversation)
    end

    it 'creates with custom person' do
      person = create(:person)
      participant = create(:conversation_participant, person: person)
      expect(participant.person).to eq(person)
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:conversation) }
    it { is_expected.to belong_to(:person) }
  end

  describe 'database constraints' do
    it 'ensures conversation cannot be null' do
      participant = build(:conversation_participant, conversation: nil)
      expect { participant.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'ensures person cannot be null' do
      participant = build(:conversation_participant, person: nil)
      expect { participant.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe 'uniqueness' do
    it 'allows same person in different conversations' do
      person = create(:person)
      conversation1 = create(:conversation)
      conversation2 = create(:conversation)

      participant1 = create(:conversation_participant, person: person, conversation: conversation1)
      participant2 = build(:conversation_participant, person: person, conversation: conversation2)

      expect(participant1).to be_persisted
      expect(participant2).to be_valid
    end

    it 'allows different people in same conversation' do
      conversation = create(:conversation)
      person1 = create(:person)
      person2 = create(:person)

      participant1 = create(:conversation_participant, person: person1, conversation: conversation)
      participant2 = build(:conversation_participant, person: person2, conversation: conversation)

      expect(participant1).to be_persisted
      expect(participant2).to be_valid
    end
  end
end
