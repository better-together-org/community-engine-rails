# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ListOffersTool, type: :model do
  let(:user) { create(:user) }
  let(:person) { user.person }
  let!(:own_offer) { create(:better_together_joatu_offer, creator: person) }

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('offer')
    end
  end

  describe '#call' do
    it 'returns accessible offers' do
      tool = described_class.new
      result = JSON.parse(tool.call)

      ids = result.map { |o| o['id'] }
      expect(ids).to include(own_offer.id)
    end

    it 'returns offer attributes' do
      tool = described_class.new
      result = JSON.parse(tool.call)
      next if result.empty?

      offer = result.first
      expect(offer).to have_key('id')
      expect(offer).to have_key('name')
      expect(offer).to have_key('status')
      expect(offer).to have_key('urgency')
    end

    it 'filters by status when provided' do
      tool = described_class.new
      result = JSON.parse(tool.call(status: 'open'))

      statuses = result.map { |o| o['status'] }
      expect(statuses).to all(eq('open'))
    end

    it 'respects limit parameter' do
      tool = described_class.new
      result = JSON.parse(tool.call(limit: 1))

      expect(result.length).to be <= 1
    end

    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns valid JSON array for anonymous users' do
        tool = described_class.new
        result = JSON.parse(tool.call)

        expect(result).to be_an(Array)
      end
    end
  end
end
