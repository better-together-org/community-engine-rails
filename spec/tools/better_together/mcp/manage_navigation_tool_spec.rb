# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ManageNavigationTool, type: :model do
  let(:user) { create(:user) }
  let!(:nav_area) { create(:better_together_navigation_area, visible: true) }
  let!(:nav_item) { create(:better_together_navigation_item, navigation_area: nav_area, visible: true) }

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('navigation')
    end
  end

  describe '#call' do
    it 'returns navigation areas with items' do
      tool = described_class.new
      result = JSON.parse(tool.call)

      area_ids = result.map { |a| a['id'] }
      expect(area_ids).to include(nav_area.id)
    end

    it 'includes items in each area' do
      tool = described_class.new
      result = JSON.parse(tool.call)
      area = result.find { |a| a['id'] == nav_area.id }

      expect(area['items']).to be_an(Array)
      item_ids = area['items'].map { |i| i['id'] }
      expect(item_ids).to include(nav_item.id)
    end

    it 'returns item attributes' do
      tool = described_class.new
      result = JSON.parse(tool.call)
      area = result.find { |a| a['id'] == nav_area.id }
      next if area['items'].empty?

      item = area['items'].first
      expect(item).to have_key('id')
      expect(item).to have_key('title')
      expect(item).to have_key('url')
      expect(item).to have_key('position')
    end

    it 'filters to a specific area when area_id provided' do
      other_area = create(:better_together_navigation_area)
      tool = described_class.new
      result = JSON.parse(tool.call(area_id: nav_area.id))

      area_ids = result.map { |a| a['id'] }
      expect(area_ids).to include(nav_area.id)
      expect(area_ids).not_to include(other_area.id)
    end

    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns navigation areas (publicly viewable)' do
        tool = described_class.new
        result = JSON.parse(tool.call)

        expect(result).to be_an(Array)
      end
    end
  end
end
