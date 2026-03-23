# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ListEventsTool, type: :model do
  let(:user) { create(:user) }

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has helpful description' do
      expect(described_class.description).to include('List events')
    end
  end

  describe '#call' do
    context 'when listing public events' do
      let!(:public_event) { create(:event, privacy: 'public', name: 'Public Event') }
      let!(:private_event) { create(:event, privacy: 'private', name: 'Private Event') }

      it 'returns public events' do
        tool = described_class.new
        result = tool.call

        events = JSON.parse(result)
        event_names = events.map { |e| e['name'] }
        expect(event_names).to include('Public Event')
      end
    end

    context 'when filtering by scope' do
      let!(:upcoming_event) { create(:event, :upcoming, privacy: 'public', name: 'Upcoming Event') }
      let!(:past_event) { create(:event, :past, privacy: 'public', name: 'Past Event') }

      it 'returns only upcoming events when scope is upcoming' do
        tool = described_class.new
        result = tool.call(scope: 'upcoming')

        events = JSON.parse(result)
        event_names = events.map { |e| e['name'] }
        expect(event_names).to include('Upcoming Event')
        expect(event_names).not_to include('Past Event')
      end
    end

    context 'when user is not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      let!(:public_event) { create(:event, privacy: 'public', name: 'Public Event') }

      it 'returns only public events' do
        tool = described_class.new
        result = tool.call

        events = JSON.parse(result)
        expect(events).to be_an(Array)
      end
    end
  end
end
