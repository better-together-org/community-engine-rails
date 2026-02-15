# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::CreatePostTool, type: :model do
  let(:user) { create(:user) }
  let(:manager_user) { create(:user, :platform_manager) }

  before do
    configure_host_platform
  end

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('post')
    end
  end

  describe '#call' do
    let(:valid_params) do
      {
        title: 'My New Post',
        content: 'This is the post content with enough detail.'
      }
    end

    context 'when authenticated with create permissions' do
      before { stub_mcp_request_for(described_class, user: manager_user) }

      it 'creates a draft post by default' do
        tool = described_class.new
        result = JSON.parse(tool.call(**valid_params))

        expect(result).to have_key('id')
        expect(result['status']).to eq('draft')
        expect(result['title']).to eq('My New Post')
      end

      it 'creates a published post when publish is true' do
        tool = described_class.new
        result = JSON.parse(tool.call(**valid_params, publish: true))

        expect(result).to have_key('id')
        expect(result['status']).to eq('published')
        expect(result).to have_key('published_at')
      end

      it 'returns post URL' do
        tool = described_class.new
        result = JSON.parse(tool.call(**valid_params))

        expect(result).to have_key('url')
      end

      it 'sets privacy level' do
        tool = described_class.new
        result = JSON.parse(tool.call(**valid_params, privacy: 'private'))

        expect(result['privacy']).to eq('private')
      end

      it 'creates a new post record' do
        tool = described_class.new
        expect do
          tool.call(**valid_params)
        end.to change(BetterTogether::Post, :count).by(1)
      end
    end

    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns error' do
        tool = described_class.new
        result = JSON.parse(tool.call(**valid_params))

        expect(result).to have_key('error')
        expect(result['error']).to include('Authentication required')
      end
    end
  end
end
