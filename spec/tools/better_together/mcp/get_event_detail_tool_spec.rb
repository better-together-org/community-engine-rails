# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::GetEventDetailTool, type: :model do
  let(:user) { create(:user) }

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has helpful description' do
      expect(described_class.description).to include('Get detailed information')
    end
  end

  describe '#call' do
    context 'when event exists and is accessible' do
      let(:event) { create(:event, privacy: 'public', name: 'Detailed Event') }

      it 'returns event details' do
        tool = described_class.new
        result = tool.call(event_id: event.id)

        data = JSON.parse(result)
        expect(data['name']).to eq('Detailed Event')
        expect(data).to have_key('starts_at')
        expect(data).to have_key('timezone')
        expect(data).to have_key('attendee_count')
      end
    end

    context 'when event does not exist' do
      it 'returns error message' do
        tool = described_class.new
        result = tool.call(event_id: SecureRandom.uuid)

        data = JSON.parse(result)
        expect(data['error']).to include('not found')
      end
    end
  end
end
