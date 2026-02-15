# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::CreateEventTool, type: :model do
  let(:user) { create(:user) }
  let(:manager_user) { create(:user, :platform_manager) }

  before do
    configure_host_platform
  end

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('Create')
      expect(described_class.description).to include('event')
    end
  end

  describe '#call' do
    let(:valid_params) do
      {
        name: 'Community Meetup',
        description: 'A great community event',
        starts_at: 1.week.from_now.iso8601,
        ends_at: (1.week.from_now + 2.hours).iso8601,
        timezone: 'America/New_York',
        privacy: 'public'
      }
    end

    context 'when authenticated with create permissions' do
      before { stub_mcp_request_for(described_class, user: manager_user) }

      it 'creates an event' do
        tool = described_class.new
        result = JSON.parse(tool.call(**valid_params))

        expect(result).to have_key('id')
        expect(result['name']).to eq('Community Meetup')
      end

      it 'returns event URL' do
        tool = described_class.new
        result = JSON.parse(tool.call(**valid_params))

        expect(result).to have_key('url')
      end

      it 'sets privacy level' do
        tool = described_class.new
        result = JSON.parse(tool.call(**valid_params, privacy: 'private'))

        expect(result['privacy']).to eq('private')
      end
    end

    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns error' do
        tool = described_class.new
        result = JSON.parse(tool.call(**valid_params))

        expect(result).to have_key('error')
        expect(result['error']).to include('Authentication required')
      end
    end
  end
end
