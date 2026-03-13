# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::UpdatePostTool, type: :model do
  let(:manager_user) { create(:user, :platform_manager) }
  let(:regular_user) { create(:user) }
  let!(:post) do
    create(:post,
           title: 'Original Title',
           content: 'Original content.',
           creator: manager_user.person,
           privacy: 'public',
           published_at: Time.current)
  end

  before { configure_host_platform }

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('Update')
    end
  end

  describe '#call' do
    context 'when authenticated with update permissions' do
      before { stub_mcp_request_for(described_class, user: manager_user) }

      it 'updates the post title' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: post.id, title: 'New Title'))

        expect(result['title']).to eq('New Title')
        expect(post.reload.title).to eq('New Title')
      end

      it 'updates the post privacy' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: post.id, privacy: 'private'))

        expect(result['privacy']).to eq('private')
        expect(post.reload.privacy).to eq('private')
      end

      it 'updates the post content' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: post.id, content: 'Updated content.'))

        expect(result).to have_key('id')
        expect(post.reload.content.to_plain_text).to include('Updated content.')
      end

      it 'returns post URL' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: post.id, title: 'Test'))

        expect(result).to have_key('url')
      end

      it 'returns error for non-existent post' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: SecureRandom.uuid))

        expect(result['error']).to include('not found')
      end
    end

    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns authentication error' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: post.id, title: 'Hack'))

        expect(result['error']).to include('Authentication required')
      end
    end

    context 'when authenticated without manage_platform permission' do
      before { stub_mcp_request_for(described_class, user: regular_user) }

      it 'returns authorization error' do
        tool = described_class.new
        result = JSON.parse(tool.call(post_id: post.id, title: 'Hack'))

        expect(result['error']).to include('Not authorized')
      end
    end
  end
end
