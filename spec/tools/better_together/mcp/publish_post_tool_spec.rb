# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::PublishPostTool, type: :model do
  let(:manager_user) { create(:user, :platform_manager) }
  let(:regular_user) { create(:user) }
  let!(:draft_post) do
    create(:post,
           title: 'Draft Post',
           creator: manager_user.person,
           privacy: 'public',
           published_at: nil)
  end
  let!(:published_post) do
    create(:post,
           title: 'Published Post',
           creator: manager_user.person,
           privacy: 'public',
           published_at: 1.day.ago)
  end

  before { configure_host_platform }

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('publish')
    end
  end

  describe '#call' do
    context 'when authenticated with update permissions' do
      before { stub_mcp_request_for(described_class, user: manager_user) }

      it 'publishes a draft post' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: draft_post.id, publish: true))

        expect(result['status']).to eq('published')
        expect(result['published_at']).to be_present
        expect(draft_post.reload.published?).to be true
      end

      it 'unpublishes a published post' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: published_post.id, publish: false))

        expect(result['status']).to eq('draft')
        expect(result['published_at']).to be_nil
        expect(published_post.reload.published?).to be false
      end

      it 'returns post URL' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: draft_post.id, publish: true))

        expect(result).to have_key('url')
      end

      it 'returns error for non-existent post' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: SecureRandom.uuid, publish: true))

        expect(result['error']).to include('not found')
      end
    end

    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns authentication error' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: draft_post.id, publish: true))

        expect(result['error']).to include('Authentication required')
      end
    end

    context 'when authenticated without manage_platform permission' do
      before { stub_mcp_request_for(described_class, user: regular_user) }

      it 'returns authorization error' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: draft_post.id, publish: true))

        expect(result['error']).to include('Not authorized')
      end
    end
  end
end
