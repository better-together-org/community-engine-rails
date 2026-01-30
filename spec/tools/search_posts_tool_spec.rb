# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::SearchPostsTool, type: :model do
  let(:user) { create(:user) }
  let(:blocked_user) { create(:user) }
  let!(:post1) do
    create(:post,
           title: 'Ruby on Rails Tutorial',
           creator: user.person,
           privacy: 'public',
           published_at: Time.current)
  end
  let!(:post2) do
    create(:post,
           title: 'Private Ruby Guide',
           creator: user.person,
           privacy: 'private',
           published_at: Time.current)
  end
  let!(:blocked_post) do
    create(:post,
           title: 'Ruby Tips',
           creator: blocked_user.person,
           privacy: 'public',
           published_at: Time.current)
  end

  before do
    configure_host_platform
    create(:person_block, blocker: user.person, blocked: blocked_user.person)
    allow_any_instance_of(described_class).to receive(:request).and_return(
      instance_double(Rack::Request, params: { 'user_id' => user.id })
    )
  end

  describe '.description' do
    it 'has helpful description' do
      expect(described_class.description).to include('Search published posts')
    end
  end

  describe '.name' do
    it 'has correct name' do
      expect(described_class.name).to be_present
    end
  end

  describe '#call' do
    it 'searches posts by query string' do
      tool = described_class.new
      result = tool.call(query: 'Tutorial')

      posts = JSON.parse(result)
      expect(posts.length).to eq(1)
      expect(posts.first['title']).to eq('Ruby on Rails Tutorial')
    end

    it 'excludes private posts from other users' do
      other_user = create(:user)
      allow_any_instance_of(described_class).to receive(:request).and_return(
        instance_double(Rack::Request, params: { 'user_id' => other_user.id })
      )

      tool = described_class.new
      result = tool.call(query: 'Ruby')

      posts = JSON.parse(result)
      titles = posts.map { |p| p['title'] }
      expect(titles).not_to include('Private Ruby Guide')
      expect(titles).to include('Ruby on Rails Tutorial')
    end

    it 'includes own private posts' do
      tool = described_class.new
      result = tool.call(query: 'Ruby')

      posts = JSON.parse(result)
      titles = posts.map { |p| p['title'] }
      expect(titles).to include('Ruby on Rails Tutorial', 'Private Ruby Guide')
    end

    it 'excludes posts from blocked users' do
      tool = described_class.new
      result = tool.call(query: 'Ruby')

      posts = JSON.parse(result)
      titles = posts.map { |p| p['title'] }
      expect(titles).not_to include('Ruby Tips')
    end

    it 'includes essential post information' do
      tool = described_class.new
      result = tool.call(query: 'Tutorial')

      posts = JSON.parse(result)
      post = posts.first

      expect(post).to have_key('id')
      expect(post).to have_key('title')
      expect(post).to have_key('excerpt')
      expect(post).to have_key('published_at')
      expect(post).to have_key('creator_name')
    end

    context 'when unauthenticated' do
      before do
        allow_any_instance_of(described_class).to receive(:request).and_return(
          instance_double(Rack::Request, params: {})
        )
      end

      it 'returns only public posts' do
        tool = described_class.new
        result = tool.call(query: 'Ruby')

        posts = JSON.parse(result)
        expect(posts.length).to eq(2) # post1 and blocked_post (both public)
        titles = posts.map { |p| p['title'] }
        expect(titles).not_to include('Private Ruby Guide')
      end
    end
  end
end
