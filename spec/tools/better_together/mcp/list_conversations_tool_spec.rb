# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ListConversationsTool, type: :model do
  let(:user) { create(:user) }
  let(:person) { user.person }

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has helpful description' do
      expect(described_class.description).to include('List conversations')
    end
  end

  describe '#call' do
    context 'when user has conversations' do
      let!(:conversation) do
        conv = create(:conversation, creator: person)
        conv.participants << person unless conv.participants.include?(person)
        conv
      end

      it 'returns user conversations' do
        tool = described_class.new
        result = tool.call

        data = JSON.parse(result)
        expect(data).to be_an(Array)
        expect(data.length).to be >= 1

        conv_data = data.find { |c| c['id'] == conversation.id }
        expect(conv_data).not_to be_nil
        expect(conv_data).to have_key('title')
        expect(conv_data).to have_key('participant_count')
      end
    end

    context 'when user is not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns error message' do
        tool = described_class.new
        result = tool.call

        data = JSON.parse(result)
        expect(data['error']).to include('Authentication required')
      end
    end
  end
end
