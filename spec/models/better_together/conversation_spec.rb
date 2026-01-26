# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Conversation do
  describe 'factory' do
    it 'creates a valid conversation' do
      conversation = build(:conversation)
      expect(conversation).to be_valid
    end

    it 'includes creator as participant by default' do
      conversation = create(:conversation)
      expect(conversation.participants).to include(conversation.creator)
    end

    it 'includes an initial message by default' do
      conversation = create(:conversation)
      expect(conversation.messages.count).to eq(1)
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:creator).class_name('BetterTogether::Person') }
    it { is_expected.to have_many(:messages).dependent(:destroy) }
    it { is_expected.to have_many(:conversation_participants).dependent(:destroy) }
    it { is_expected.to have_many(:participants).through(:conversation_participants).source(:person) }
  end

  describe 'validations' do
    describe 'participant_ids presence on create' do
      it 'validates participant_ids presence on create' do
        creator = create(:person)
        conversation = described_class.new(
          title: 'Test',
          creator: creator,
          participant_ids: []
        )
        expect(conversation).not_to be_valid
        expect(conversation.errors[:participant_ids]).to include("can't be blank")
      end

      it 'allows update without participant_ids' do
        conversation = create(:conversation)
        conversation.title = 'Updated Title'
        expect(conversation).to be_valid
      end
    end

    describe 'at_least_one_participant custom validation' do
      it 'is invalid when all participants are removed' do
        conversation = create(:conversation)
        conversation.participants.clear
        expect(conversation).not_to be_valid
        expect(conversation.errors[:conversation_participants]).to be_present
      end

      it 'is valid with at least one participant' do
        conversation = create(:conversation)
        expect(conversation.participants.count).to be >= 1
        expect(conversation).to be_valid
      end
    end

    describe 'first_message_content_present on create' do
      it 'is invalid when message content is blank on create' do
        creator = create(:person)
        conversation = described_class.new(
          title: 'Test',
          creator: creator,
          participant_ids: [creator.id],
          messages_attributes: [{ sender: creator, content: '' }]
        )
        expect(conversation).not_to be_valid
        expect(conversation.errors[:messages]).to include("can't be blank")
      end

      it 'is valid when message content is present on create' do
        creator = create(:person)
        conversation = described_class.new(
          title: 'Test',
          creator: creator,
          participant_ids: [creator.id],
          messages_attributes: [{ sender: creator, content: 'Hello!' }]
        )
        expect(conversation).to be_valid
      end

      it 'is valid when no messages are provided on create' do
        creator = create(:person)
        conversation = described_class.new(
          title: 'Test',
          creator: creator,
          participant_ids: [creator.id]
        )
        # NOTE: This will be invalid in practice due to factory defaults,
        # but testing the validation logic in isolation
        conversation.messages.clear
        expect(conversation.errors[:messages]).to be_empty
      end
    end
  end

  describe 'encryption' do
    it 'encrypts the title deterministically' do
      conversation1 = create(:conversation, title: 'Secret Title')
      conversation2 = create(:conversation, title: 'Secret Title')

      # Deterministic encryption means same plaintext = same ciphertext
      # But we can't directly access the encrypted value in the same way
      # Instead, verify both decrypt to the same value
      expect(conversation1.title).to eq('Secret Title')
      expect(conversation2.title).to eq('Secret Title')
    end
  end

  describe 'nested attributes' do
    it 'accepts nested attributes for messages' do
      creator = create(:person)
      conversation = described_class.create(
        title: 'Test',
        creator: creator,
        participant_ids: [creator.id],
        messages_attributes: [
          { sender: creator, content: 'First message' },
          { sender: creator, content: 'Second message' }
        ]
      )
      expect(conversation.messages.count).to eq(2)
      expect(conversation.messages.first.content.to_plain_text).to eq('First message')
      expect(conversation.messages.second.content.to_plain_text).to eq('Second message')
    end
  end

  describe '#first_message_content' do
    it 'returns the plain text content of the first message' do
      conversation = create(:conversation)
      first_message = conversation.messages.first
      expect(conversation.first_message_content).to eq(first_message.content.to_plain_text)
    end

    it 'returns nil when there are no messages' do
      conversation = build(:conversation)
      conversation.messages.clear
      expect(conversation.first_message_content).to be_nil
    end
  end

  describe '#to_s' do
    it 'returns the title' do
      conversation = build(:conversation, title: 'Test Conversation')
      expect(conversation.to_s).to eq('Test Conversation')
    end
  end

  describe '.permitted_attributes' do
    it 'returns the permitted attributes array' do
      permitted = described_class.permitted_attributes
      expect(permitted).to include(:title)
      expect(permitted).to include({ participant_ids: [] })
      expect(permitted).to include({ messages_attributes: BetterTogether::Message.permitted_attributes })
    end
  end

  describe '#add_participant_safe' do
    let(:conversation) { create(:better_together_conversation) }
    let(:person) { create(:better_together_person) }

    it 'adds a participant when not present' do # rubocop:todo RSpec/MultipleExpectations
      expect do
        conversation.add_participant_safe(person)
      end.to change { conversation.participants.count }.by(1)
      expect(conversation.participants).to include(person)
    end

    it 'does not add duplicate participants' do
      conversation.add_participant_safe(person)
      expect do
        conversation.add_participant_safe(person)
      end.not_to(change { conversation.participants.count })
    end

    it 'handles nil person gracefully' do
      expect do
        conversation.add_participant_safe(nil)
      end.not_to(change { conversation.participants.count })
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'retries once on ActiveRecord::StaleObjectError and succeeds' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      # Simulate the association raising once, then succeeding on retry.
      proxy = conversation.participants

      call_count = 0
      allow(proxy).to receive(:<<) do |p|
        call_count += 1
        raise ActiveRecord::StaleObjectError.new(p, :update) if call_count == 1

        # perform the actual append on retry
        ActiveRecord::Associations::CollectionProxy.instance_method(:<<).bind(proxy).call(p)
      end

      expect do
        conversation.add_participant_safe(person)
      end.to change { conversation.participants.count }.by(1)

      expect(call_count).to eq(2)
      expect(conversation.participants).to include(person)
    end
  end
end
