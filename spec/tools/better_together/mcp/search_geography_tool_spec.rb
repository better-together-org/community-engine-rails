# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::SearchGeographyTool, type: :model do
  let(:user) { create(:user) }
  let!(:continent) { create(:better_together_geography_continent) }
  let!(:country) { create(:better_together_geography_country) }

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('geography')
    end
  end

  describe '#call' do
    it 'returns matching locations' do
      tool = described_class.new
      result = JSON.parse(tool.call(query: continent.identifier))

      ids = result.map { |l| l['id'] }
      expect(ids).to include(continent.id)
    end

    it 'returns location attributes' do
      tool = described_class.new
      result = JSON.parse(tool.call(query: continent.identifier))
      next if result.empty?

      location = result.first
      expect(location).to have_key('id')
      expect(location).to have_key('name')
      expect(location).to have_key('type')
      expect(location).to have_key('identifier')
    end

    it 'filters by location_type when provided' do
      tool = described_class.new
      result = JSON.parse(tool.call(query: country.identifier, location_type: 'country'))

      types = result.map { |l| l['type'] }
      expect(types).to all(eq('country'))
    end

    it 'respects limit parameter' do
      tool = described_class.new
      result = JSON.parse(tool.call(query: continent.identifier, limit: 1))

      expect(result.length).to be <= 1
    end

    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns valid JSON array for anonymous users' do
        tool = described_class.new
        result = JSON.parse(tool.call(query: continent.identifier))

        expect(result).to be_an(Array)
      end
    end
  end
end
