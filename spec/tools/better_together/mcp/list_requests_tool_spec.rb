# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ListRequestsTool, type: :model do
  let(:user) { create(:user) }
  let(:person) { user.person }
  let!(:own_request) { create(:better_together_joatu_request, creator: person) }

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('request')
    end
  end

  describe '#call' do
    it 'returns accessible requests' do
      tool = described_class.new
      result = JSON.parse(tool.call)

      ids = result.map { |r| r['id'] }
      expect(ids).to include(own_request.id)
    end

    it 'returns request attributes' do
      tool = described_class.new
      result = JSON.parse(tool.call)
      next if result.empty?

      req = result.first
      expect(req).to have_key('id')
      expect(req).to have_key('name')
      expect(req).to have_key('status')
      expect(req).to have_key('urgency')
    end

    it 'filters by urgency when provided' do
      tool = described_class.new
      result = JSON.parse(tool.call(urgency: 'normal'))

      urgencies = result.map { |r| r['urgency'] }
      expect(urgencies).to all(eq('normal'))
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
