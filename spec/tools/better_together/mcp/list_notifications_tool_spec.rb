# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ListNotificationsTool, type: :model do
  let(:user) { create(:user) }
  let(:person) { user.person }

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has helpful description' do
      expect(described_class.description).to include('List notifications')
    end
  end

  describe '#call' do
    context 'when user has notifications' do
      before do
        create(:noticed_notification, recipient: person)
        create(:noticed_notification, recipient: person, read_at: Time.current)
      end

      it 'returns notifications with unread count' do
        tool = described_class.new
        result = tool.call

        data = JSON.parse(result)
        expect(data).to have_key('notifications')
        expect(data).to have_key('unread_count')
        expect(data['notifications'].length).to eq(2)
      end

      it 'returns only unread when filtered' do
        tool = described_class.new
        result = tool.call(unread_only: true)

        data = JSON.parse(result)
        expect(data['notifications'].length).to eq(1)
        expect(data['notifications'].first['read']).to be(false)
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
