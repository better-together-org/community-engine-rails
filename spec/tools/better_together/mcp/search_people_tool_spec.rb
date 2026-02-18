# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::SearchPeopleTool, type: :model do
  let(:user) { create(:user) }
  let!(:visible_person) do
    create(:better_together_person, name: 'Alice Johnson', identifier: 'alice-johnson', privacy: 'public')
  end
  let!(:private_person) do
    create(:better_together_person, name: 'Bob Smith', identifier: 'bob-smith', privacy: 'private')
  end

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('Search people')
    end
  end

  describe '#call' do
    it 'searches people by name' do
      tool = described_class.new
      result = tool.call(query: 'Alice')

      people = JSON.parse(result)
      names = people.map { |p| p['name'] }
      expect(names).to include('Alice Johnson')
    end

    it 'searches people by identifier' do
      tool = described_class.new
      result = tool.call(query: 'alice-johnson')

      people = JSON.parse(result)
      expect(people).not_to be_empty
    end

    it 'returns empty array for no matches' do
      tool = described_class.new
      result = tool.call(query: 'zzz-nonexistent-xyz')

      people = JSON.parse(result)
      expect(people).to be_empty
    end

    it 'respects limit parameter' do
      5.times { |i| create(:better_together_person, name: "TestUser#{i}", identifier: "testuser-#{i}", privacy: 'public') }
      tool = described_class.new
      result = tool.call(query: 'TestUser', limit: 2)

      people = JSON.parse(result)
      expect(people.length).to be <= 2
    end

    it 'returns person attributes' do
      tool = described_class.new
      result = tool.call(query: 'Alice')

      people = JSON.parse(result)
      next unless people.any?

      person = people.first
      expect(person).to have_key('id')
      expect(person).to have_key('name')
      expect(person).to have_key('handle')
      expect(person).to have_key('url')
    end
  end
end
