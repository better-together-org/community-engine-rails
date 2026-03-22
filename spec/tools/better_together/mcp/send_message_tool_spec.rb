# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::SendMessageTool, type: :model do
  let(:user) { create(:user) }
  let(:person) { user.person }
  let(:other_person) { create(:better_together_person) }
  let(:conversation) { create(:better_together_conversation) }

  before do
    configure_host_platform
    # Add both as participants
    create(:better_together_conversation_participant, conversation: conversation, person: person)
    create(:better_together_conversation_participant, conversation: conversation, person: other_person)
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('message')
    end
  end

  describe '#call' do
    it 'sends a message to the conversation' do
      tool = described_class.new
      result = JSON.parse(tool.call(conversation_id: conversation.id, content: 'Hello there!'))

      expect(result).to have_key('id')
      expect(result).to have_key('sent_at')
    end

    it 'creates a new message record' do
      tool = described_class.new
      expect do
        tool.call(conversation_id: conversation.id, content: 'Test message')
      end.to change(BetterTogether::Message, :count).by(1)
    end

    it 'returns error for non-participant conversation' do
      other_conversation = create(:better_together_conversation)
      tool = described_class.new
      result = JSON.parse(tool.call(conversation_id: other_conversation.id, content: 'Intruder!'))

      expect(result).to have_key('error')
      expect(result['error']).to include('not found')
    end

    it 'returns error for non-existent conversation' do
      tool = described_class.new
      result = JSON.parse(tool.call(conversation_id: SecureRandom.uuid, content: 'Hello'))

      expect(result).to have_key('error')
    end

    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns error' do
        tool = described_class.new
        result = JSON.parse(tool.call(conversation_id: conversation.id, content: 'Hello'))

        expect(result).to have_key('error')
        expect(result['error']).to include('Authentication required')
      end
    end
  end
end
