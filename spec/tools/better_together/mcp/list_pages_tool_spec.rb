# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ListPagesTool, type: :model do
  let(:user) { create(:user) }
  let(:person) { user.person }
  let!(:published_page) { create(:better_together_page, :published_public) }
  let!(:unpublished_page) { create(:better_together_page, :unpublished) }

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('page')
    end
  end

  describe '#call' do
    it 'returns published pages' do
      tool = described_class.new
      result = JSON.parse(tool.call)

      ids = result.map { |p| p['id'] }
      expect(ids).to include(published_page.id)
    end

    it 'returns page attributes' do
      tool = described_class.new
      result = JSON.parse(tool.call)
      next if result.empty?

      page = result.first
      expect(page).to have_key('id')
      expect(page).to have_key('title')
      expect(page).to have_key('slug')
      expect(page).to have_key('privacy')
    end

    it 'filters by privacy when provided' do
      tool = described_class.new
      result = JSON.parse(tool.call(privacy: 'public'))

      privacies = result.map { |p| p['privacy'] }
      expect(privacies).to all(eq('public'))
    end

    it 'respects limit parameter' do
      3.times { create(:better_together_page, :published_public) }
      tool = described_class.new
      result = JSON.parse(tool.call(limit: 2))

      expect(result.length).to be <= 2
    end

    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns pages visible to anonymous users' do
        tool = described_class.new
        result = JSON.parse(tool.call)

        expect(result).to be_an(Array)
      end
    end
  end
end
