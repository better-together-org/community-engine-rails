# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::GetMetricsSummaryTool, type: :model do
  let(:manager_user) { create(:user, :platform_manager) }
  let(:regular_user) { create(:user) }

  before do
    configure_host_platform
  end

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('metrics')
    end
  end

  describe '#call' do
    context 'when authenticated as platform manager' do
      before do
        stub_mcp_request_for(described_class, user: manager_user)
        3.times do |i|
          BetterTogether::Metrics::PageView.create!(
            page_url: "/test-page-#{i}",
            locale: 'en',
            viewed_at: Time.current
          )
        end
      end

      it 'returns metrics summary' do
        tool = described_class.new
        result = JSON.parse(tool.call)

        expect(result).to have_key('total_page_views')
        expect(result['total_page_views']).to be >= 3
      end

      it 'includes unique pages count' do
        tool = described_class.new
        result = JSON.parse(tool.call)

        expect(result).to have_key('unique_pages')
      end

      it 'includes views by locale' do
        tool = described_class.new
        result = JSON.parse(tool.call)

        expect(result).to have_key('views_by_locale')
        expect(result['views_by_locale']).to be_a(Hash)
      end

      it 'includes top pages' do
        tool = described_class.new
        result = JSON.parse(tool.call)

        expect(result).to have_key('top_pages')
      end

      it 'supports date range filtering' do
        tool = described_class.new
        result = JSON.parse(tool.call(from_date: 7.days.ago.to_date.to_s, to_date: Date.current.to_s))

        expect(result).to have_key('total_page_views')
      end
    end

    context 'when authenticated as regular user' do
      before { stub_mcp_request_for(described_class, user: regular_user) }

      it 'returns error message' do
        tool = described_class.new
        result = JSON.parse(tool.call)

        expect(result).to have_key('error')
        expect(result['error']).to include('Platform manager')
      end
    end

    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns error message' do
        tool = described_class.new
        result = JSON.parse(tool.call)

        expect(result).to have_key('error')
      end
    end
  end
end
