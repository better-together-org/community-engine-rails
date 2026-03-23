# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::SearchPagesTool, type: :model do
  let(:user) { create(:user) }
  let!(:matching_page) do
    create(:better_together_page, :published_public,
           title: 'Employment Resources for Newcomers')
  end
  let!(:other_page) do
    create(:better_together_page, :published_public,
           title: 'Community Events')
  end
  let!(:unpublished_page) do
    create(:better_together_page, :unpublished,
           title: 'Employment Draft')
  end

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
    it 'searches pages by title' do
      tool = described_class.new
      result = JSON.parse(tool.call(query: 'Employment'))

      ids = result.map { |p| p['id'] }
      expect(ids).to include(matching_page.id)
      expect(ids).not_to include(other_page.id)
    end

    it 'returns essential page attributes including slug and url' do
      tool = described_class.new
      result = JSON.parse(tool.call(query: 'Employment'))

      page = result.first
      expect(page).to have_key('id')
      expect(page).to have_key('title')
      expect(page).to have_key('slug')
      expect(page).to have_key('privacy')
      expect(page).to have_key('published_at')
      expect(page).to have_key('url')
    end

    it 'excludes unpublished pages' do
      tool = described_class.new
      result = JSON.parse(tool.call(query: 'Employment'))

      ids = result.map { |p| p['id'] }
      expect(ids).not_to include(unpublished_page.id)
    end

    it 'respects the limit parameter' do
      3.times { create(:better_together_page, :published_public, title: 'Employment Info') }
      tool = described_class.new
      result = JSON.parse(tool.call(query: 'Employment', limit: 2))

      expect(result.length).to be <= 2
    end

    context 'when unauthenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns only public pages' do
        tool = described_class.new
        result = JSON.parse(tool.call(query: 'Employment'))

        expect(result).to be_an(Array)
        privacies = result.map { |p| p['privacy'] }
        expect(privacies).to all(eq('public'))
      end
    end
  end
end
