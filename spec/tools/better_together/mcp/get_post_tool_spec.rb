# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::GetPostTool, type: :model do
  let(:user) { create(:user) }

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has helpful description' do
      expect(described_class.description).to include('Get a specific published post')
    end
  end

  describe '#call' do
    context 'when post exists and is accessible' do
      let(:test_post) { create(:better_together_post, privacy: 'public', published_at: 1.day.ago) }

      it 'returns post details' do
        tool = described_class.new
        result = tool.call(post_id: test_post.id)

        data = JSON.parse(result)
        expect(data['title']).to eq(test_post.title)
        expect(data).to have_key('content')
        expect(data).to have_key('excerpt')
        expect(data).to have_key('url')
      end
    end

    context 'when post does not exist' do
      it 'returns error message' do
        tool = described_class.new
        result = tool.call(post_id: SecureRandom.uuid)

        data = JSON.parse(result)
        expect(data['error']).to include('not found')
      end
    end
  end
end
